import { generateText } from "ai";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { extractLyricsPrompt } from "../prompts/extractLyrics.ts";
import { message, withRetries } from "../retry.ts";
import { transcribeWithSupadata, transcriptToLines } from "../supadata.ts";

const MAX_GEMINI_RETRIES = 2;

export async function extractLyrics(ctx: PipelineContext): Promise<void> {
  const { store } = ctx;
  let attempts = 0;
  let lastResponseText: string | null = null;

  try {
    await store.patch([
      { op: "set", path: "extract_lyrics_in_progress", value: true },
      { op: "set", path: "force_alignment_in_progress", value: true },
    ]);

    const languageCode = languageCodeForTranscription(ctx.clipLanguage, ctx.clipLanguageIso);
    const transcribe = ctx.transcribeVideo ?? transcribeWithSupadata;
    let lyricLines: string[];
    try {
      const transcript = await transcribe(ctx.youtubeurl, languageCode);
      lyricLines = transcriptToLines(transcript.content);
      if (lyricLines.length === 0) throw new Error("Supadata returned no usable native transcript");
    } catch (nativeError) {
      if (!isYoutubeUrl(ctx.youtubeurl)) throw nativeError;
      console.warn(`ExtractLyrics falling back to Gemini: ${message(nativeError)}`);
      lyricLines = await withRetries(
        async () => {
          const { text } = await generateText({
            model: ctx.models.extractLyrics,
            system: extractLyricsPrompt(ctx.clipLanguage),
            messages: [{
              role: "user",
              content: [{ type: "file", data: new URL(ctx.youtubeurl), mediaType: "video/mp4" }],
            }],
            temperature: 0.2,
          });
          lastResponseText = text;
          const parsed = parseLyricsLines(text);
          if (parsed.length === 0) throw new Error("Gemini lyrics response contained no lines");
          return parsed;
        },
        {
          maxRetries: MAX_GEMINI_RETRIES,
          label: "ExtractLyrics Gemini",
          baseDelayMs: ctx.baseDelayMs,
          onFailedAttempt: (_error, attempt) => (attempts = Math.max(attempts, attempt)),
        },
      );
    }
    await store.patch([
      { op: "set", path: "lyric_lines", value: lyricLines },
      { op: "set", path: "extract_lyrics_in_progress", value: false },
    ]);
    await clearErrors(ctx, "extract_lyrics");
  } catch (error) {
    await recordError(ctx, "extract_lyrics", error, {
      attempts: attempts || undefined,
      agent_response: lastResponseText,
    });
    console.error(`Transcript extraction failed: ${message(error)}`);
    throw error;
  }
}

export function parseLyricsLines(text: string): string[] {
  return text
    .replace(/^```\w*\s*/m, "")
    .replace(/```\s*$/m, "")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

export function isYoutubeUrl(value: string): boolean {
  try {
    const hostname = new URL(value).hostname.toLowerCase().replace(/^www\./, "");
    return hostname === "youtube.com" || hostname.endsWith(".youtube.com") ||
      hostname === "youtu.be";
  } catch {
    return false;
  }
}

const LANGUAGE_TO_ISO: Record<string, string> = {
  english: "en",
  french: "fr",
  german: "de",
  hebrew: "he",
  russian: "ru",
  spanish: "es",
  arabic: "ar",
};

export function languageCodeForTranscription(
  clipLanguage: string,
  clipLanguageIso?: string | null,
): string | null {
  return clipLanguageIso ?? LANGUAGE_TO_ISO[clipLanguage.toLowerCase()] ?? null;
}
