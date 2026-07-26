import { generateObject } from "ai";
import { z } from "zod";
import type { Phrase } from "../types.ts";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { message, withRetries } from "../retry.ts";
import { downloadYoutubeAudioToTemp, isAudioVerificationUnavailable } from "../audio.ts";
import { type AlignedWord, alignLyrics as alignWithElevenLabs } from "../alignment.ts";
import { phrasesFromAlignedWords } from "../alignedWords.ts";
import { fallbackWordTimestampsPrompt } from "../prompts/fallbackWordTimestamps.ts";

const MAX_AUDIO_RETRIES = 2;
const MAX_ALIGN_RETRIES = 2;
const MAX_GEMINI_RETRIES = 1;

// Word-level, not line-level, on purpose: the fallback has to hand back the
// same shape ElevenLabs does — one timed word per transcript word — because
// everything downstream (add_lessons re-partitioning, karaoke highlighting,
// the word-order activities) is built on that stream. Timing lines instead
// would leave every fallback course silently without word timings.
const fallbackOutputSchema = z.object({
  words: z.array(z.object({
    word: z.string(),
    start_seconds: z.number(),
    end_seconds: z.number(),
  })),
});

export async function forceAlignment(ctx: PipelineContext): Promise<void> {
  const lines = ctx.store.data.lyric_lines ?? [];
  let audioPath: string | null = null;
  let attempts = 0;
  let lastResponse: string | null = null;
  try {
    if (lines.length === 0) throw new Error("No lyric lines to align");
    await ctx.store.set("force_alignment_in_progress", true);
    let phrases: Phrase[];
    let videoLengthSeconds: number | null = null;

    // TikTok arrives here already timed: extract_lyrics used ElevenLabs Scribe,
    // which returns the transcript and its word timestamps together. There is
    // nothing left to align, so skip the audio download and the alignment call
    // rather than paying for both to rediscover timings we already hold.
    const sttWords = ctx.store.data.stt_words ?? [];
    if (sttWords.length > 0) {
      phrases = phrasesFromAlignedWords(sttWords);
      if (phrases.length !== 1) {
        throw new Error("Speech-to-text words produced no usable transcript");
      }
      videoLengthSeconds = sttWords.at(-1)?.end ?? null;
      await persist(ctx, phrases, videoLengthSeconds);
      await clearErrors(ctx, "force_alignment");
      return;
    }

    try {
      const audio = await withRetries(
        () => (ctx.prepareAudio ?? downloadYoutubeAudioToTemp)(ctx.youtubeurl),
        {
          maxRetries: MAX_AUDIO_RETRIES,
          label: "ForceAlignment audio",
          baseDelayMs: ctx.baseDelayMs,
          // A host that cannot verify audio will not start being able to.
          isFatal: isAudioVerificationUnavailable,
        },
      );
      audioPath = audio.path;
      const alignment = await withRetries(
        () => (ctx.alignLyrics ?? alignWithElevenLabs)(audio.path, lines.join(" ")),
        {
          maxRetries: MAX_ALIGN_RETRIES,
          label: "ForceAlignment ElevenLabs",
          baseDelayMs: ctx.baseDelayMs,
        },
      );
      phrases = phrasesFromElevenLabs(lines, alignment.words);
      videoLengthSeconds = audio.durationSeconds;
    } catch (elevenLabsError) {
      // Gemini would happily timestamp the lines from the video URL and hide the
      // fact that this host cannot verify a download — at the cost of every
      // future import silently losing word-level timings. Fix the host instead.
      if (isAudioVerificationUnavailable(elevenLabsError)) throw elevenLabsError;
      console.warn(
        `ForceAlignment falling back to Gemini word timestamps: ${message(elevenLabsError)}`,
      );
      const transcriptWords = wordsOf(lines);
      const fallback = await withRetries(
        async () => {
          const result = await generateObject({
            model: ctx.models.forceAlignmentFallback,
            schema: fallbackOutputSchema,
            system: fallbackWordTimestampsPrompt(ctx.clipLanguage),
            messages: [{
              role: "user",
              content: [
                {
                  type: "text",
                  text: `Timestamp these ${transcriptWords.length} words, in order:\n` +
                    JSON.stringify(transcriptWords),
                },
                { type: "file", data: new URL(ctx.youtubeurl), mediaType: "video/mp4" },
              ],
            }],
            temperature: 0.1,
          });
          lastResponse = JSON.stringify(result.object);
          return validateFallbackWords(transcriptWords, result.object.words);
        },
        {
          maxRetries: MAX_GEMINI_RETRIES,
          label: "ForceAlignment Gemini",
          baseDelayMs: ctx.baseDelayMs,
          onFailedAttempt: (_error, attempt) => attempts = attempt,
        },
      );
      phrases = phrasesFromFallback(transcriptWords, fallback);
      videoLengthSeconds = fallback.at(-1)?.end_seconds ?? null;
    }

    await persist(ctx, phrases, videoLengthSeconds);
    await clearErrors(ctx, "force_alignment");
  } catch (error) {
    await recordError(ctx, "force_alignment", error, {
      attempts: attempts || undefined,
      input_lines: lines.length ? lines : null,
      agent_response: lastResponse,
    });
    console.error(`Forced alignment failed: ${message(error)}`);
    throw error;
  } finally {
    if (audioPath) await Deno.remove(audioPath).catch(() => {});
  }
}

async function persist(
  ctx: PipelineContext,
  phrases: Phrase[],
  videoLengthSeconds: number | null,
): Promise<void> {
  await ctx.store.patch([
    { op: "set", path: "lyric_lines", value: phrases.map((phrase) => phrase.text_l1) },
    { op: "set", path: "phrases", value: phrases },
    ...(videoLengthSeconds == null ? [] : [{
      op: "set" as const,
      path: "video_length_seconds",
      value: videoLengthSeconds,
    }]),
    { op: "set", path: "force_alignment_in_progress", value: false },
  ]);
}

function phrasesFromElevenLabs(lines: string[], words: AlignedWord[]): Phrase[] {
  const expectedWords = wordsOf(lines).length;
  if (words.length !== expectedWords) {
    throw new Error(`ElevenLabs aligned ${words.length} of ${expectedWords} transcript words`);
  }
  const phrases = phrasesFromAlignedWords(words);
  if (phrases.length !== 1) throw new Error("ElevenLabs returned no usable transcript words");
  return phrases;
}

type FallbackWord = z.infer<typeof fallbackOutputSchema>["words"][number];

function validateFallbackWords(
  transcriptWords: string[],
  returned: FallbackWord[],
): FallbackWord[] {
  if (returned.length !== transcriptWords.length) {
    throw new Error(
      `Gemini timestamped ${returned.length} of ${transcriptWords.length} transcript words`,
    );
  }
  let previousStart = 0;
  returned.forEach((word, index) => {
    // The words are matched, not just counted: a model that quietly drops a
    // repeat and adds a word elsewhere would otherwise pass the count check
    // and shift every timestamp after it.
    if (normalizeWord(word.word) !== normalizeWord(transcriptWords[index])) {
      throw new Error(
        `Gemini returned "${word.word}" for transcript word ${index + 1} ` +
          `("${transcriptWords[index]}")`,
      );
    }
    if (
      !Number.isFinite(word.start_seconds) || !Number.isFinite(word.end_seconds) ||
      word.start_seconds < 0 || word.end_seconds < word.start_seconds ||
      word.start_seconds < previousStart
    ) {
      throw new Error(`Gemini returned invalid timestamps for transcript word ${index + 1}`);
    }
    previousStart = word.start_seconds;
  });
  return returned;
}

function phrasesFromFallback(transcriptWords: string[], timestamps: FallbackWord[]): Phrase[] {
  // Gemini contributes timings only. The text stays the transcript's own, so
  // re-punctuation or a "corrected" spelling that survived normalization still
  // cannot reach the course.
  const words: AlignedWord[] = transcriptWords.map((text, index) => ({
    text,
    start: timestamps[index].start_seconds,
    end: timestamps[index].end_seconds,
  }));
  const phrases = phrasesFromAlignedWords(words);
  if (phrases.length !== 1) throw new Error("Gemini returned no usable transcript words");
  return phrases;
}

// The transcript arrives as a single continuous line (see extract_lyrics), so
// whitespace tokens are the unit both timing providers are held to.
function wordsOf(lines: string[]): string[] {
  return lines.flatMap((line) => line.split(/\s+/u).filter(Boolean));
}

// Compare on the part that identifies the word: punctuation, quote style and
// case are the model's to get wrong without failing the run.
function normalizeWord(text: string): string {
  return text
    .normalize("NFC")
    .replace(/[‘’ʼ]/gu, "'")
    .replace(/^[\p{P}\p{S}]+|[\p{P}\p{S}]+$/gu, "")
    .toLocaleLowerCase();
}
