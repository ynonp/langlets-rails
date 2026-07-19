// Port of CreateSong::ExtractLyrics, split into two calls:
//
//   1. Gemini reads the YouTube URL directly (as a video file part) and
//      returns the plain lyrics text, one line per sung/spoken phrase.
//   2. ElevenLabs forced alignment maps every word of that text onto the
//      clip's audio track (downloaded via yt-dlp) with per-word timestamps.
//
// Transcribing and timing are separated because STT timing on sung vocals is
// unreliable: with alignment the words are ground truth and only their
// position in the audio is estimated. The aligned words are grouped back into
// the lyric lines to form the pipeline's phrase shape.

import { generateText } from "ai";
import type { Phrase } from "../types.ts";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { parseWordTimings } from "../wordTimingParser.ts";
import { timestampToSeconds } from "../timestamps.ts";
import { extractLyricsPrompt } from "../prompts/extractLyrics.ts";
import { withRetries } from "../retry.ts";
import { downloadYoutubeAudioToTemp } from "../audio.ts";
import { type AlignedWord, alignLyrics as alignWithElevenLabs } from "../alignment.ts";

// Minimum fraction of the video (by the last aligned timestamp vs. the clip
// duration) that must be covered for the step to succeed. Below this we
// assume the lyrics stopped short — Gemini bailed out early — and fail the
// pipeline rather than ship a song that's missing most of its lyrics.
export const MIN_COVERAGE_RATIO = 0.5;

// How many times to re-run a lyrics call whose response came back unusable
// (blank, only fences, ...) before giving up.
const MAX_LYRICS_RETRIES = 2;

// How many times to re-run a failed alignment request before giving up.
const MAX_ALIGN_RETRIES = 2;

export class IncompleteTranscriptionError extends Error {}

export async function extractLyrics(ctx: PipelineContext): Promise<void> {
  const { store } = ctx;
  let lastResponseText: string | null = null;
  let attempts = 0;
  let audioPath: string | null = null;

  try {
    // Mark the step as in progress before the first call. If the run dies
    // mid-step, this flag stays true and tells the resume guard to pick the
    // step back up instead of mistaking partially-saved phrases for a
    // finished transcription.
    await store.set("extract_lyrics_in_progress", true);

    // 1. Lyrics text from Gemini. The YouTube URL goes in as a file part —
    // Gemini fetches the video itself, no upload needed.
    const lines = await withRetries(
      async () => {
        const { text } = await generateText({
          model: ctx.models.extractLyrics,
          system: extractLyricsPrompt(ctx.clipLanguage),
          messages: [
            {
              role: "user",
              content: [{ type: "file", data: new URL(ctx.youtubeurl), mediaType: "video/mp4" }],
            },
          ],
          temperature: 0.2,
          providerOptions: { google: { thinkingConfig: { thinkingLevel: "medium" } } },
        });
        lastResponseText = text;
        const parsed = parseLyricsLines(text);
        if (parsed.length === 0) throw new Error("Lyrics response contained no lines");
        return parsed;
      },
      {
        maxRetries: MAX_LYRICS_RETRIES,
        label: "ExtractLyrics lyrics",
        baseDelayMs: ctx.baseDelayMs,
        onFailedAttempt: (_error, attempt) => {
          attempts = Math.max(attempts, attempt);
        },
      },
    );

    // 2. Download the audio track and force-align the lyrics to it. Retried
    // because both the YouTube download and the alignment call can fail
    // transiently.
    const audio = await withRetries(
      () => (ctx.prepareAudio ?? downloadYoutubeAudioToTemp)(ctx.youtubeurl),
      { maxRetries: 2, label: "ExtractLyrics audio", baseDelayMs: ctx.baseDelayMs },
    );
    audioPath = audio.path;

    const alignment = await withRetries(
      () => (ctx.alignLyrics ?? alignWithElevenLabs)(audio.path, lines.join("\n")),
      {
        maxRetries: MAX_ALIGN_RETRIES,
        label: "ExtractLyrics alignment",
        baseDelayMs: ctx.baseDelayMs,
        onFailedAttempt: (_error, attempt) => {
          attempts = Math.max(attempts, attempt);
        },
      },
    );

    const phrases = parseWordTimings({ lines: groupWordsByLine(lines, alignment.words) });

    const patches: { op: "set"; path: string; value: unknown }[] = [
      { op: "set", path: "phrases", value: phrases },
    ];
    if (audio.durationSeconds != null) {
      patches.push({ op: "set", path: "video_length_seconds", value: audio.durationSeconds });
    }
    await store.patch(patches);

    ensureVideoCoverage(phrases, audio.durationSeconds);

    // Reached the end with acceptable coverage — the step is done. A coverage
    // failure throws above and leaves the flag set, so the next run picks the
    // step back up.
    await store.set("extract_lyrics_in_progress", false);
    await clearErrors(ctx, "extract_lyrics");
  } catch (error) {
    await recordError(ctx, "extract_lyrics", error, {
      attempts: attempts || undefined,
      agent_response: lastResponseText,
    });
    throw error;
  } finally {
    if (audioPath) await Deno.remove(audioPath).catch(() => {});
  }
}

// The lyrics response is plain text, one line per phrase; be forgiving about
// stray markdown fences and blank separator lines.
export function parseLyricsLines(text: string): string[] {
  return text
    .replace(/^```\w*\s*/m, "")
    .replace(/```\s*$/m, "")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line !== "");
}

// The alignment text is the lyric lines joined with newlines, so the aligned
// words come back in order: walk the lines and give each one as many words as
// it has whitespace-separated tokens. Each line's timestamps span its first
// and last word. Lines left without words (the alignment ran out) are
// dropped; the coverage guard catches large gaps.
function groupWordsByLine(lines: string[], words: AlignedWord[]) {
  let next = 0;
  const grouped = [];

  for (const line of lines) {
    const tokenCount = line.split(/\s+/).filter((t) => t !== "").length;
    if (tokenCount === 0) continue;

    const lineWords = words.slice(next, next + tokenCount);
    next += tokenCount;
    if (lineWords.length === 0) break;

    grouped.push({
      line_start: secondsToSrt(lineWords[0].start),
      line_end: secondsToSrt(lineWords.at(-1)!.end),
      line_text: line,
      words: lineWords.map((w) => ({
        word: w.text,
        start: secondsToSrt(w.start),
        end: secondsToSrt(w.end),
      })),
    });
  }

  return grouped;
}

function secondsToSrt(seconds: number): string {
  const total = Math.max(0, Math.round(seconds * 1000));
  const h = Math.floor(total / 3_600_000);
  const m = Math.floor((total % 3_600_000) / 60_000);
  const s = Math.floor((total % 60_000) / 1000);
  const millis = total % 1000;
  const pad = (v: number, len = 2) => String(v).padStart(len, "0");
  return `${pad(h)}:${pad(m)}:${pad(s)},${pad(millis, 3)}`;
}

// Guard against lyrics that stop well before the end of the video (Gemini
// returned only the first verse, say): the last aligned word would then sit
// early in the clip. A missing duration means we can't judge coverage, so we
// let it through rather than fail on metadata.
function ensureVideoCoverage(phrases: Phrase[], totalSeconds: number | null): void {
  if (totalSeconds == null || totalSeconds <= 0) return;

  const coveredSeconds = Math.max(
    0,
    ...phrases.map((p) => timestampToSeconds(p.timestamp_end) ?? 0),
  );
  const ratio = coveredSeconds / totalSeconds;
  if (ratio >= MIN_COVERAGE_RATIO) return;

  throw new IncompleteTranscriptionError(
    `Transcription only covered ${Math.round(ratio * 100)}% of the video ` +
      `(${Math.round(coveredSeconds)}s of ${Math.round(totalSeconds)}s); ` +
      `at least ${Math.round(MIN_COVERAGE_RATIO * 100)}% is required.`,
  );
}
