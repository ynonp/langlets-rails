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
import { secondsToTimestamp } from "../timestamps.ts";
import { reconcileTimedTranscript } from "../reconcileTimedTranscript.ts";
import { isYoutubeUrl } from "../videoUrl.ts";

const MAX_AUDIO_RETRIES = 2;
const MAX_ALIGN_RETRIES = 2;
const MAX_GEMINI_RETRIES = 1;

// Word entries remain optional because phrase bounds are the hard requirement:
// Gemini may omit middle words, but reconciliation requires the first and last
// lexical word of every source line and preserves any other timings it returns.
const fallbackOutputSchema = z.object({
  words: z.array(z.object({
    word: z.string(),
    start_seconds: z.number().optional(),
    end_seconds: z.number().optional(),
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

    // extract_lyrics normally arrives here with a complete, conservatively
    // reconciled Scribe timing set. There is nothing left to align in that case.
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
      const scribeFallback = checkpointedScribeWords(ctx, lines);
      const cannotVerifyAudio = isAudioVerificationUnavailable(elevenLabsError);
      // Gemini URL ingestion supports YouTube, not arbitrary provider pages.
      // A checkpointed Scribe result is also safer than hiding a broken local
      // audio toolchain behind a line-only fallback.
      if (!isYoutubeUrl(ctx.youtubeurl) || cannotVerifyAudio) {
        if (scribeFallback.length === 0) throw elevenLabsError;
        console.warn(
          "ForceAlignment using checkpointed ElevenLabs timings without Gemini URL fallback",
        );
        phrases = phrasesFromAlignedWords(scribeFallback);
        videoLengthSeconds = scribeFallback.at(-1)?.end ?? null;
      } else {
        console.warn(
          `ForceAlignment falling back to Gemini word timestamps: ${message(elevenLabsError)}`,
        );
        try {
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
                      text:
                        `Timestamp these ${transcriptWords.length} words, grouped by source line:\n` +
                        JSON.stringify(lines.map((line) => wordsOf([line]))),
                    },
                    { type: "file", data: new URL(ctx.youtubeurl), mediaType: "video/mp4" },
                  ],
                }],
                temperature: 0.1,
              });
              lastResponse = JSON.stringify(result.object);
              return reconcileFallbackWords(lines, result.object.words);
            },
            {
              maxRetries: MAX_GEMINI_RETRIES,
              label: "ForceAlignment Gemini",
              baseDelayMs: ctx.baseDelayMs,
              onFailedAttempt: (_error, attempt) => attempts = attempt,
            },
          );
          phrases = phrasesFromFallback(lines, fallback);
          videoLengthSeconds = fallback.flatMap((line) => line.words)
            .at(-1)?.timestamp?.end_seconds ?? null;
        } catch (geminiError) {
          if (scribeFallback.length === 0) throw geminiError;
          console.warn(
            `ForceAlignment Gemini failed; using checkpointed ElevenLabs timings: ` +
              message(geminiError),
          );
          phrases = phrasesFromAlignedWords(scribeFallback);
          videoLengthSeconds = scribeFallback.at(-1)?.end ?? null;
        }
      }
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

function checkpointedScribeWords(ctx: PipelineContext, lines: string[]): AlignedWord[] {
  const words = ctx.store.data.stt_candidates?.elevenlabs?.words ?? [];
  return words.length === 0 ? [] : reconcileTimedTranscript(lines.join(" "), words).words;
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
  const phrases = phrasesFromAlignedWords(reconcileToTranscript(wordsOf(lines), words));
  if (phrases.length !== 1) throw new Error("ElevenLabs returned no usable transcript words");
  return phrases;
}

interface TimedChar {
  char: string;
  start: number;
  end: number;
}

// ElevenLabs tokenizes the text it is given however it likes: "don't" can come
// back as "don" + "'t", "(x2)" can vanish, and a script without word spaces is
// split per character. Its tokenization cannot be the pipeline's, because the
// transcript's own whitespace tokens are what add_lessons indexes into and what
// add_token_translations turns into one clickable word each — so a provider
// that splits "don't" would ship "'t" as a vocabulary item.
//
// So take from ElevenLabs only what it is uniquely able to give — timings —
// exactly as the Gemini fallback already does (see phrasesFromFallback), and
// keep the transcript's own tokens. Timings are carried on a stream of timed
// characters, which lets one transcript word draw from several aligned words
// (a split) or a fraction of one (a merge) without either case being special.
export function reconcileToTranscript(
  transcriptWords: string[],
  aligned: AlignedWord[],
): AlignedWord[] {
  const chars = timedChars(aligned);
  const words: AlignedWord[] = [];
  let cursor = 0;

  for (const text of transcriptWords) {
    // Punctuation-only tokens (a stray dash, the ♪ that YouTube wraps every
    // caption line in) have no audio to be timed against and no meaning to be
    // translated. Dropping them here keeps them out of the word stream, and so
    // out of the reconstructed line text.
    const key = [...alignmentKey(text)];
    if (key.length === 0) continue;

    const slice = chars.slice(cursor, cursor + key.length);
    const got = slice.map((timed) => timed.char).join("");
    if (got !== key.join("")) {
      throw new Error(
        `ElevenLabs aligned "${got}" where the transcript has "${key.join("")}" ` +
          `(transcript word ${words.length + 1}, "${text}")`,
      );
    }
    words.push({ text, start: slice[0].start, end: slice.at(-1)!.end });
    cursor += key.length;
  }

  if (cursor < chars.length) {
    throw new Error(
      `ElevenLabs aligned ${chars.length - cursor} characters past the end of the transcript`,
    );
  }
  return words;
}

// Spread each aligned word's span evenly across its own characters. Sub-word
// precision is invented, but it is only ever consumed at word boundaries the
// provider itself did not draw — and the alternative, refusing the alignment,
// costs the whole audio-derived timing set.
function timedChars(words: AlignedWord[]): TimedChar[] {
  return words.flatMap((word) => {
    const key = [...alignmentKey(word.text)];
    const span = Math.max(0, word.end - word.start);
    return key.map((char, index) => ({
      char,
      start: word.start + span * index / key.length,
      end: word.start + span * (index + 1) / key.length,
    }));
  });
}

// The identity of a word for matching purposes: the letters and digits, with
// case, spacing and punctuation left to whichever side wants them. Compared
// character by character, so unlike normalizeWord this strips punctuation
// throughout rather than only at the edges.
function alignmentKey(text: string): string {
  return text
    .normalize("NFC")
    .replace(/[‘’ʼ]/gu, "'")
    .replace(/[\s\p{P}\p{S}]+/gu, "")
    .toLocaleLowerCase();
}

type FallbackWord = z.infer<typeof fallbackOutputSchema>["words"][number];
type TimedFallbackWord = FallbackWord & {
  start_seconds: number;
  end_seconds: number;
};

interface ReconciledFallbackWord {
  text: string;
  timestamp?: TimedFallbackWord;
}

interface ReconciledFallbackLine {
  text: string;
  words: ReconciledFallbackWord[];
}

function reconcileFallbackWords(
  lines: string[],
  returned: FallbackWord[],
): ReconciledFallbackLine[] {
  const timedReturned = returned.map((word, index) => {
    if (word.start_seconds === undefined || word.end_seconds !== undefined) return word;
    const nextStart = returned.slice(index + 1)
      .find((candidate) => candidate.start_seconds !== undefined)
      ?.start_seconds;
    return {
      ...word,
      end_seconds: nextStart ?? word.start_seconds + 2,
    };
  });

  let previousStart = 0;
  timedReturned.forEach((word, index) => {
    const hasStart = word.start_seconds !== undefined;
    const hasEnd = word.end_seconds !== undefined;
    if (!hasStart && !hasEnd) return;
    if (
      !hasStart || !hasEnd ||
      !Number.isFinite(word.start_seconds) || !Number.isFinite(word.end_seconds) ||
      word.start_seconds! < 0 || word.end_seconds! < word.start_seconds! ||
      word.start_seconds! < previousStart
    ) {
      throw new Error(`Gemini returned invalid timestamps for transcript word ${index + 1}`);
    }
    previousStart = word.start_seconds!;
  });

  let returnedIndex = 0;
  const reconciled = lines.map((text) => ({
    text,
    words: wordsOf([text]).map((word) => {
      const candidate = timedReturned[returnedIndex];
      if (candidate && normalizeWord(candidate.word) === normalizeWord(word)) {
        returnedIndex++;
        return candidate.start_seconds !== undefined && candidate.end_seconds !== undefined
          ? { text: word, timestamp: candidate as TimedFallbackWord }
          : { text: word };
      }
      return { text: word };
    }),
  }));

  if (returnedIndex !== timedReturned.length) {
    throw new Error(
      `Gemini returned "${timedReturned[returnedIndex].word}" outside the transcript word order`,
    );
  }

  reconciled.forEach((line, index) => {
    const matchable = line.words.filter((word) => normalizeWord(word.text) !== "");
    if (
      matchable.length === 0 ||
      !matchable[0].timestamp ||
      !matchable.at(-1)!.timestamp
    ) {
      throw new Error(
        `Gemini did not timestamp the first and last words of transcript line ${index + 1}`,
      );
    }
  });

  return reconciled;
}

function phrasesFromFallback(
  lines: string[],
  reconciled: ReconciledFallbackLine[],
): Phrase[] {
  // Gemini contributes timings only. The text stays the transcript's own, so
  // re-punctuation or a "corrected" spelling that survived normalization still
  // cannot reach the course.
  return reconciled.map((line, lineIndex) => {
    const timedWords = line.words.filter((word) => word.timestamp);
    let cursor = 0;
    const words = line.words.map((word) => {
      const start = line.text.indexOf(word.text, cursor);
      cursor = start < 0 ? cursor : start + word.text.length;
      return {
        text: word.text,
        ...(word.timestamp
          ? {
            timestamp: secondsToTimestamp(word.timestamp.start_seconds),
            timestamp_end: secondsToTimestamp(word.timestamp.end_seconds),
          }
          : {}),
        ...(start < 0 ? {} : { l1_start_index: start, l1_end_index: start + word.text.length - 1 }),
      };
    });

    return {
      id: `phrase_${lineIndex + 1}`,
      text_l1: lines[lineIndex],
      timestamp: secondsToTimestamp(timedWords[0].timestamp!.start_seconds),
      timestamp_end: secondsToTimestamp(timedWords.at(-1)!.timestamp!.end_seconds),
      words,
    };
  });
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
