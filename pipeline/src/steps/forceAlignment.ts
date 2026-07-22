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
      () => (ctx.alignLyrics ?? alignWithElevenLabs)(audio.path, lines.join("\n")),
      {
        maxRetries: MAX_ALIGN_RETRIES,
        label: "ForceAlignment ElevenLabs",
        baseDelayMs: ctx.baseDelayMs,
        onFailedAttempt: (_error, attempt) => attempts = Math.max(attempts, attempt),
      },
    );
    const phrases: Phrase[] = parseWordTimings({ lines: groupWordsByLine(lines, alignment.words) });
    if (phrases.length !== lines.length) {
      throw new Error(`ElevenLabs aligned ${phrases.length} of ${lines.length} transcript lines`);
    }
    await ctx.store.patch([
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

function groupWordsByLine(lines: string[], words: AlignedWord[]) {
  let next = 0;
  return lines.flatMap((line) => {
    const count = line.split(/\s+/u).filter(Boolean).length;
    const lineWords = words.slice(next, next + count);
    next += count;
    if (lineWords.length !== count) return [];
    return [{
      line_start: secondsToSrt(lineWords[0].start),
      line_end: secondsToSrt(lineWords.at(-1)!.end),
      line_text: line,
      words: lineWords.map((word) => ({
        word: word.text,
        start: secondsToSrt(word.start),
        end: secondsToSrt(word.end),
      })),
    }];
  });
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
