// First half of the old CreateSong::ExtractLyrics: Gemini reads the YouTube
// URL directly (as a video file part) and returns the plain lyrics text, one
// line per sung/spoken phrase. The lines are saved to data.lyric_lines and
// timed separately by the force_alignment step.
//
// Transcribing and timing are separated because STT timing on sung vocals is
// unreliable: with forced alignment the words are ground truth and only their
// position in the audio is estimated. Splitting them into two pipeline steps
// also means a failed alignment never costs us the transcription — a rerun
// picks up the saved lines and only retries the timing.

import { generateText } from "ai";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { extractLyricsPrompt } from "../prompts/extractLyrics.ts";
import { withRetries } from "../retry.ts";

// How many times to re-run a lyrics call whose response came back unusable
// (blank, only fences, ...) before giving up.
const MAX_LYRICS_RETRIES = 2;

export async function extractLyrics(ctx: PipelineContext): Promise<void> {
  const { store } = ctx;
  let lastResponseText: string | null = null;
  let attempts = 0;

  try {
    // Mark the step as in progress before the first call. If the run dies
    // mid-step, this flag stays true and tells the resume guard to pick the
    // step back up instead of mistaking partially-saved lines for a finished
    // transcription.
    await store.set("extract_lyrics_in_progress", true);

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

    // New lines invalidate whatever phrases a previous run left behind: they
    // were timed against a different transcription. Flagging alignment as
    // unfinished here is what makes the next step rerun instead of trusting
    // those stale phrases.
    await store.patch([
      { op: "set", path: "lyric_lines", value: lines },
      { op: "set", path: "force_alignment_in_progress", value: true },
      { op: "set", path: "extract_lyrics_in_progress", value: false },
    ]);
    await clearErrors(ctx, "extract_lyrics");
  } catch (error) {
    await recordError(ctx, "extract_lyrics", error, {
      attempts: attempts || undefined,
      agent_response: lastResponseText,
    });
    throw error;
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
