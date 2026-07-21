// Second half of the old CreateSong::ExtractLyrics: take the lyric lines the
// extract_lyrics step saved and put a timestamp on every word.
//
// Primary path — yt-dlp downloads the clip's audio track and ElevenLabs forced
// alignment maps the known words onto it. The aligned words are grouped back
// into the lyric lines to form the pipeline's phrase shape.
//
// Backup path — when that fails (yt-dlp blocked or rate-limited, ElevenLabs
// erroring, an alignment that came back empty) Gemini watches the YouTube clip
// and times the same lines itself. Its timings are looser than true forced
// alignment, so it is only ever a fallback; a song with slightly soft word
// boundaries still beats a song with none.

import { generateText } from "ai";
import type { Phrase } from "../types.ts";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { parseWordTimings } from "../wordTimingParser.ts";
import { timestampToSeconds } from "../timestamps.ts";
import { forceAlignmentPrompt } from "../prompts/forceAlignment.ts";
import { message, withRetries } from "../retry.ts";
import { downloadYoutubeAudioToTemp, type DownloadedAudio } from "../audio.ts";
import { type AlignedWord, alignLyrics as alignWithElevenLabs } from "../alignment.ts";

// Minimum fraction of the video (by the last aligned timestamp vs. the clip
// duration) that must be covered for the step to succeed. Below this we
// assume the lyrics stopped short — Gemini bailed out early during
// transcription — and fail the pipeline rather than ship a song that's
// missing most of its lyrics.
export const MIN_COVERAGE_RATIO = 0.5;

// How many times to re-run a failed audio download / alignment request before
// falling back to Gemini.
const MAX_AUDIO_RETRIES = 2;
const MAX_ALIGN_RETRIES = 2;

// How many times to re-run an unusable backup response before giving up.
const MAX_BACKUP_RETRIES = 1;

export class IncompleteTranscriptionError extends Error {}

export async function forceAlignment(ctx: PipelineContext): Promise<void> {
  const { store } = ctx;
  let lines: string[] = store.data.lyric_lines ?? [];
  let attempts = 0;
  let backupResponse: string | null = null;
  let audioPath: string | null = null;

  try {
    // Mark the step as in progress before the first call. If the run dies
    // mid-step, this flag stays true and tells the resume guard to pick the
    // step back up instead of mistaking partially-saved phrases for finished
    // alignment.
    await store.set("force_alignment_in_progress", true);

    // The duration comes from the yt-dlp download, so it survives an
    // ElevenLabs failure and still guards the backup's coverage. It's only
    // null when the download itself never got that far.
    let durationSeconds: number | null = null;
    let phrases: Phrase[];

    // Download audio once — used for forced alignment. If the download
    // fails, fall back to Gemini for timing.
    let audio: DownloadedAudio;
    try {
      audio = await withRetries(
        () => (ctx.prepareAudio ?? downloadYoutubeAudioToTemp)(ctx.youtubeurl),
        {
          maxRetries: MAX_AUDIO_RETRIES,
          label: "ForceAlignment audio",
          baseDelayMs: ctx.baseDelayMs,
        },
      );
      audioPath = audio.path;
      durationSeconds = audio.durationSeconds;
    } catch (error) {
      if (lines.length === 0) throw error;

      console.warn(`ForceAlignment falling back to Gemini (audio download failed): ${message(error)}`);
      phrases = await alignWithGemini(ctx, lines, error, {
        onResponse: (text) => (backupResponse = text),
        onFailedAttempt: (attempt) => (attempts = Math.max(attempts, attempt)),
      });
      await store.set("phrases", phrases);
      await store.set("force_alignment_in_progress", false);
      await clearErrors(ctx, "force_alignment");
      return;
    }

    try {
      const alignment = await withRetries(
        () => (ctx.alignLyrics ?? alignWithElevenLabs)(audioPath!, lines.join("\n")),
        {
          maxRetries: MAX_ALIGN_RETRIES,
          label: "ForceAlignment alignment",
          baseDelayMs: ctx.baseDelayMs,
          onFailedAttempt: (_error, attempt) => {
            attempts = Math.max(attempts, attempt);
          },
        },
      );

      phrases = parseWordTimings({ lines: groupWordsByLine(lines, alignment.words) });
      if (phrases.length === 0) throw new Error("Alignment returned no timed words");
    } catch (error) {
      // Primary path is out. Try Gemini rather than losing the transcription;
      // if the backup fails too, the thrown error names both causes.
      console.warn(`ForceAlignment falling back to Gemini: ${message(error)}`);
      phrases = await alignWithGemini(ctx, lines, error, {
        onResponse: (text) => (backupResponse = text),
        onFailedAttempt: (attempt) => (attempts = Math.max(attempts, attempt)),
      });
    }

    const patches: { op: "set"; path: string; value: unknown }[] = [
      { op: "set", path: "phrases", value: phrases },
    ];
    if (durationSeconds != null) {
      patches.push({ op: "set", path: "video_length_seconds", value: durationSeconds });
    }
    await store.patch(patches);

    ensureVideoCoverage(phrases, durationSeconds);

    // Reached the end with acceptable coverage — the step is done. A coverage
    // failure throws above and leaves the flag set, so the next run picks the
    // step back up.
    await store.set("force_alignment_in_progress", false);
    await clearErrors(ctx, "force_alignment");
  } catch (error) {
    await recordError(ctx, "force_alignment", error, {
      attempts: attempts || undefined,
      input_lines: lines.length > 0 ? lines : null,
      agent_response: backupResponse ?? null,
    });
    throw error;
  } finally {
    if (audioPath) await Deno.remove(audioPath).catch(() => {});
  }
}

interface BackupHooks {
  onResponse: (text: string) => void;
  onFailedAttempt: (attempt: number) => void;
}

// Backup timing: hand Gemini the YouTube URL (as a video file part, same as
// the transcription call) plus the known lyrics, and ask for line and per-word
// timestamps in the shape parseWordTimings already reads.
async function alignWithGemini(
  ctx: PipelineContext,
  lines: string[],
  primaryError: unknown,
  hooks: BackupHooks,
): Promise<Phrase[]> {
  try {
    return await withRetries(
      async () => {
        const { text } = await generateText({
          model: ctx.models.forceAlignment,
          system: forceAlignmentPrompt(ctx.clipLanguage),
          messages: [
            {
              role: "user",
              content: [
                { type: "file", data: new URL(ctx.youtubeurl), mediaType: "video/mp4" },
                { type: "text", text: `Lyrics to time:\n${lines.join("\n")}` },
              ],
            },
          ],
          temperature: 0.2,
          providerOptions: { google: { thinkingConfig: { thinkingLevel: "medium" } } },
        });
        hooks.onResponse(text);

        const phrases = parseWordTimings(text);
        if (phrases.length === 0) throw new Error("Backup alignment response contained no lines");
        return phrases;
      },
      {
        maxRetries: MAX_BACKUP_RETRIES,
        label: "ForceAlignment backup",
        baseDelayMs: ctx.baseDelayMs,
        onFailedAttempt: (_error, attempt) => hooks.onFailedAttempt(attempt),
      },
    );
  } catch (backupError) {
    throw new Error(
      `Forced alignment failed (${message(primaryError)}) and the Gemini backup ` +
        `also failed: ${message(backupError)}`,
    );
  }
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
// transcribed only the first verse, say): the last aligned word would then sit
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
