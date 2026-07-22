import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { message, withRetries } from "../retry.ts";
import { transcribeWithSupadata, transcriptToLines } from "../supadata.ts";

const MAX_TRANSCRIPTION_RETRIES = 2;

export async function extractLyrics(ctx: PipelineContext): Promise<void> {
  const { store } = ctx;
  let attempts = 0;

  try {
    await store.patch([
      { op: "set", path: "extract_lyrics_in_progress", value: true },
      { op: "set", path: "force_alignment_in_progress", value: true },
    ]);

    const languageCode = languageCodeForTranscription(ctx.clipLanguage, ctx.clipLanguageIso);
    const transcribe = ctx.transcribeVideo ?? transcribeWithSupadata;
    const transcript = await withRetries(
      () => transcribe(ctx.youtubeurl, languageCode),
      {
        maxRetries: MAX_TRANSCRIPTION_RETRIES,
        label: "ExtractLyrics Supadata",
        baseDelayMs: ctx.baseDelayMs,
        onFailedAttempt: (_error, attempt) => (attempts = Math.max(attempts, attempt)),
      },
    );
    const lyricLines = transcriptToLines(transcript.content);
    if (lyricLines.length === 0) throw new Error("Supadata returned no usable transcript text");
    await store.patch([
      { op: "set", path: "lyric_lines", value: lyricLines },
      { op: "set", path: "extract_lyrics_in_progress", value: false },
    ]);
    await clearErrors(ctx, "extract_lyrics");
  } catch (error) {
    await recordError(ctx, "extract_lyrics", error, { attempts: attempts || undefined });
    console.error(`Supadata transcription failed: ${message(error)}`);
    throw error;
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
