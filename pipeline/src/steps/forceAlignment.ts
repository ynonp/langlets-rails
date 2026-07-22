import type { Phrase } from "../types.ts";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { parseWordTimings } from "../wordTimingParser.ts";
import { message, withRetries } from "../retry.ts";
import { downloadYoutubeAudioToTemp } from "../audio.ts";
import { type AlignedWord, alignLyrics as alignWithElevenLabs } from "../alignment.ts";

const MAX_AUDIO_RETRIES = 2;
const MAX_ALIGN_RETRIES = 2;

export async function forceAlignment(ctx: PipelineContext): Promise<void> {
  const lines = ctx.store.data.lyric_lines ?? [];
  let audioPath: string | null = null;
  let attempts = 0;
  try {
    if (lines.length === 0) throw new Error("No lyric lines to align");
    await ctx.store.set("force_alignment_in_progress", true);
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
        onFailedAttempt: (_error, attempt) => attempts = Math.max(attempts, attempt),
      },
    );
    // Provider cue boundaries are not semantic lyric lines. Send one continuous
    // transcript to ElevenLabs and keep its result as one provisional phrase;
    // addLessons later partitions these exact timed words into comprehension
    // units and lessons in one model call.
    const expectedWords = countWords(lines);
    if (alignment.words.length !== expectedWords) {
      throw new Error(
        `ElevenLabs aligned ${alignment.words.length} of ${expectedWords} transcript words`,
      );
    }
    const continuousText = alignment.words.map((word) => word.text).join(" ").trim();
    const phrases: Phrase[] = parseWordTimings({ lines: [toRawLine(alignment.words)] });
    if (phrases.length !== 1) throw new Error("ElevenLabs returned no usable transcript words");
    await ctx.store.patch([
      { op: "set", path: "lyric_lines", value: [continuousText] },
      { op: "set", path: "phrases", value: phrases },
      ...(audio.durationSeconds == null ? [] : [{
        op: "set" as const,
        path: "video_length_seconds",
        value: audio.durationSeconds,
      }]),
      { op: "set", path: "force_alignment_in_progress", value: false },
    ]);
    await clearErrors(ctx, "force_alignment");
  } catch (error) {
    await recordError(ctx, "force_alignment", error, {
      attempts: attempts || undefined,
      input_lines: lines.length ? lines : null,
    });
    console.error(`ElevenLabs forced alignment failed: ${message(error)}`);
    throw error;
  } finally {
    if (audioPath) await Deno.remove(audioPath).catch(() => {});
  }
}

function countWords(lines: string[]): number {
  return lines.reduce((total, line) => total + line.split(/\s+/u).filter(Boolean).length, 0);
}

function toRawLine(words: AlignedWord[]) {
  return {
    line_start: secondsToSrt(words[0].start),
    line_end: secondsToSrt(words.at(-1)!.end),
    line_text: words.map((word) => word.text).join(" ").trim(),
    words: words.map((word) => ({
      word: word.text,
      start: secondsToSrt(word.start),
      end: secondsToSrt(word.end),
    })),
  };
}

function secondsToSrt(seconds: number): string {
  const total = Math.max(0, Math.round(seconds * 1000));
  const hours = Math.floor(total / 3_600_000);
  const minutes = Math.floor((total % 3_600_000) / 60_000);
  const secs = Math.floor((total % 60_000) / 1000);
  const millis = total % 1000;
  const pad = (value: number, length = 2) => String(value).padStart(length, "0");
  return `${pad(hours)}:${pad(minutes)}:${pad(secs)},${pad(millis, 3)}`;
}
