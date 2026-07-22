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
import { message, withRetries } from "../retry.ts";
import { downloadYoutubeAudioToTemp } from "../audio.ts";
import {
  transcribeWithElevenLabs,
  sttTextToLines,
  languageCodeForStt,
} from "../transcription.ts";

// How many times to re-run a lyrics call whose response came back unusable
// (blank, only fences, ...) before giving up.
const MAX_LYRICS_RETRIES = 2;

// How many times to re-run the STT fallback before giving up.
const MAX_STT_RETRIES = 2;

export async function extractLyrics(ctx: PipelineContext): Promise<void> {
  const { store } = ctx;
  let lastResponseText: string | null = null;
  let attempts = 0;
  let audioPath: string | null = null;

  try {
    // Mark the step as in progress before the first call. If the run dies
    // mid-step, this flag stays true and tells the resume guard to pick the
    // step back up instead of mistaking partially-saved lines for a finished
    // transcription.
    await store.set("extract_lyrics_in_progress", true);

    let lines: string[];

    try {
      // Primary path: Gemini watches the video and transcribes the lyrics.
      lines = await withRetries(
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
            // providerOptions: { google: { thinkingConfig: { thinkingLevel: "low" } } },
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
    } catch (geminiError) {
      // Gemini couldn't produce lyrics — fall back to ElevenLabs STT.
      // Download the audio track and transcribe it.
      console.warn(`ExtractLyrics falling back to STT: ${message(geminiError)}`);

      const audio = await (ctx.prepareAudio ?? downloadYoutubeAudioToTemp)(ctx.youtubeurl);
      audioPath = audio.path;

      const langCode = languageCodeForStt(ctx.clipLanguage, ctx.clipLanguageIso);
      const transcribe = ctx.transcribeAudio ?? transcribeWithElevenLabs;
      const sttResult = await withRetries(
        () => transcribe(audioPath!, langCode),
        {
          maxRetries: MAX_STT_RETRIES,
          label: "ExtractLyrics STT",
          baseDelayMs: ctx.baseDelayMs,
          onFailedAttempt: (_error, attempt) => {
            attempts = Math.max(attempts, attempt);
          },
        },
      );

      lastResponseText = sttResult.text;
      lines = sttTextToLines(sttResult.text);
      if (lines.length === 0) {
        throw new Error(
          `Gemini lyrics failed (${message(geminiError)}) and STT fallback produced no usable lines`,
        );
      }
    }

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
