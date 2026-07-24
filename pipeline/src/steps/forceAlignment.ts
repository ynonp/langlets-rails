import { generateObject } from "ai";
import { z } from "zod";
import type { Phrase } from "../types.ts";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { message, withRetries } from "../retry.ts";
import { downloadYoutubeAudioToTemp } from "../audio.ts";
import { type AlignedWord, alignLyrics as alignWithElevenLabs } from "../alignment.ts";
import { phrasesFromAlignedWords } from "../alignedWords.ts";
import { secondsToTimestamp } from "../timestamps.ts";
import { fallbackLineTimestampsPrompt } from "../prompts/fallbackLineTimestamps.ts";

const MAX_AUDIO_RETRIES = 2;
const MAX_ALIGN_RETRIES = 2;
const MAX_GEMINI_RETRIES = 1;

const fallbackOutputSchema = z.object({
  lines: z.array(z.object({
    line: z.string(),
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
      console.warn(
        `ForceAlignment falling back to Gemini line timestamps: ${message(elevenLabsError)}`,
      );
      const fallback = await withRetries(
        async () => {
          const result = await generateObject({
            model: ctx.models.forceAlignmentFallback,
            schema: fallbackOutputSchema,
            system: fallbackLineTimestampsPrompt(ctx.clipLanguage),
            messages: [{
              role: "user",
              content: [
                {
                  type: "text",
                  text: `Timestamp these lines:\n${JSON.stringify(lines)}`,
                },
                { type: "file", data: new URL(ctx.youtubeurl), mediaType: "video/mp4" },
              ],
            }],
            temperature: 0.1,
          });
          lastResponse = JSON.stringify(result.object);
          return validateFallbackLines(lines, result.object.lines);
        },
        {
          maxRetries: MAX_GEMINI_RETRIES,
          label: "ForceAlignment Gemini",
          baseDelayMs: ctx.baseDelayMs,
          onFailedAttempt: (_error, attempt) => attempts = attempt,
        },
      );
      phrases = phrasesFromFallback(lines, fallback);
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
  const expectedWords = countWords(lines);
  if (words.length !== expectedWords) {
    throw new Error(`ElevenLabs aligned ${words.length} of ${expectedWords} transcript words`);
  }
  const phrases = phrasesFromAlignedWords(words);
  if (phrases.length !== 1) throw new Error("ElevenLabs returned no usable transcript words");
  return phrases;
}

type FallbackLine = z.infer<typeof fallbackOutputSchema>["lines"][number];

function validateFallbackLines(originalLines: string[], returned: FallbackLine[]): FallbackLine[] {
  if (returned.length !== originalLines.length) {
    throw new Error(
      `Gemini timestamped ${returned.length} of ${originalLines.length} transcript lines`,
    );
  }
  let previousEnd = 0;
  returned.forEach((line, index) => {
    if (
      !Number.isFinite(line.start_seconds) || !Number.isFinite(line.end_seconds) ||
      line.start_seconds < 0 || line.end_seconds < line.start_seconds ||
      line.start_seconds < previousEnd
    ) {
      throw new Error(`Gemini returned invalid timestamps for transcript line ${index + 1}`);
    }
    previousEnd = line.end_seconds;
  });
  return returned;
}

function phrasesFromFallback(originalLines: string[], timestamps: FallbackLine[]): Phrase[] {
  return originalLines.map((text, index) => {
    const words = [...text.matchAll(/['\p{L}][\p{L}\p{M}]*(?:'[\p{L}\p{M}]+)*/gu)].map(
      (match) => ({
        text: match[0],
        l1_start_index: match.index!,
        l1_end_index: match.index! + match[0].length - 1,
      }),
    );
    return {
      id: `phrase_${index + 1}`,
      text_l1: text,
      timestamp: secondsToTimestamp(timestamps[index].start_seconds),
      timestamp_end: secondsToTimestamp(timestamps[index].end_seconds),
      words,
    };
  });
}

function countWords(lines: string[]): number {
  return lines.reduce((total, line) => total + line.split(/\s+/u).filter(Boolean).length, 0);
}
