import { generateText } from "ai";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { extractLyricsPrompt } from "../prompts/extractLyrics.ts";
import { message, withRetries } from "../retry.ts";
import { transcribeWithSupadata, transcriptToText } from "../supadata.ts";
import {
  isSpeechToTextRequestRejected,
  type SpeechToTextResult,
  transcribeFileWithElevenLabs,
  transcribeWithElevenLabs,
} from "../speechToText.ts";
import { downloadYoutubeAudioToTemp } from "../audio.ts";

const MAX_GEMINI_RETRIES = 2;
const MAX_STT_RETRIES = 2;
const MAX_AUDIO_RETRIES = 2;

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

    // TikTok takes a different route entirely: ElevenLabs Scribe reads the post
    // URL directly and returns the transcript *and* per-word timestamps in one
    // call. So there is nothing for Supadata or Gemini to do here, and — because
    // the words are already timed — nothing for forced alignment to do either.
    // The timed words are stashed for force_alignment to pick up, so a run that
    // dies between the two steps resumes without paying for Scribe twice.
    if (isTiktokUrl(ctx.youtubeurl)) {
      const stt = await transcribeTiktok(ctx, languageCode, (attempt) => {
        attempts = Math.max(attempts, attempt);
      });
      await store.patch([
        { op: "set", path: "lyric_lines", value: [stt.text] },
        { op: "set", path: "stt_words", value: stt.words },
        { op: "set", path: "extract_lyrics_in_progress", value: false },
      ]);
      await clearErrors(ctx, "extract_lyrics");
      return;
    }

    const transcribe = ctx.transcribeVideo ?? transcribeWithSupadata;
    let lyricLines: string[];
    try {
      const transcript = await transcribe(ctx.youtubeurl, languageCode);
      const transcriptText = transcriptToText(transcript.content);
      lyricLines = transcriptText ? [transcriptText] : [];
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
          if (parsed.length === 0) throw new Error("Gemini lyrics response contained no text");
          return [parsed.join(" ")];
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

// Scribe normally reads the TikTok post URL itself. When TikTok blocks that
// server-side fetch ElevenLabs answers 400, which no amount of retrying the same
// URL will change — so download the audio (yt-dlp with the silent-HEVC
// workaround) and upload the bytes instead. Everything else about the TikTok
// route is unchanged: still one call, still transcript plus word timestamps.
async function transcribeTiktok(
  ctx: PipelineContext,
  languageCode: string | null,
  onAttempt: (attempt: number) => void,
): Promise<SpeechToTextResult> {
  try {
    return await withRetries(
      () => (ctx.transcribeSpeech ?? transcribeWithElevenLabs)(ctx.youtubeurl, languageCode),
      {
        maxRetries: MAX_STT_RETRIES,
        label: "ExtractLyrics ElevenLabs speech-to-text",
        baseDelayMs: ctx.baseDelayMs,
        onFailedAttempt: (_error, attempt) => onAttempt(attempt),
        isFatal: isSpeechToTextRequestRejected,
      },
    );
  } catch (sourceUrlError) {
    if (!isSpeechToTextRequestRejected(sourceUrlError)) throw sourceUrlError;
    console.warn(
      `ExtractLyrics falling back to downloaded audio: ${message(sourceUrlError)}`,
    );
    const audio = await withRetries(
      () => (ctx.prepareAudio ?? downloadYoutubeAudioToTemp)(ctx.youtubeurl),
      {
        maxRetries: MAX_AUDIO_RETRIES,
        label: "ExtractLyrics audio",
        baseDelayMs: ctx.baseDelayMs,
      },
    );
    try {
      return await withRetries(
        () => (ctx.transcribeSpeechFile ?? transcribeFileWithElevenLabs)(audio.path, languageCode),
        {
          maxRetries: MAX_STT_RETRIES,
          label: "ExtractLyrics ElevenLabs speech-to-text (uploaded audio)",
          baseDelayMs: ctx.baseDelayMs,
          onFailedAttempt: (_error, attempt) => onAttempt(attempt),
        },
      );
    } finally {
      await Deno.remove(audio.path).catch(() => {});
    }
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
  return hostnameOf(
    value,
    (hostname) =>
      hostname === "youtube.com" || hostname.endsWith(".youtube.com") ||
      hostname === "youtu.be",
  );
}

// Covers the post form (www.tiktok.com/@user/video/123) and the share forms
// (vt./vm.tiktok.com). Rails canonicalizes through oEmbed before the pipeline
// is triggered, so in practice this sees the post form — but Scribe accepts
// either, and the rake task can be handed a raw link.
export function isTiktokUrl(value: string): boolean {
  return hostnameOf(
    value,
    (hostname) => hostname === "tiktok.com" || hostname.endsWith(".tiktok.com"),
  );
}

function hostnameOf(value: string, predicate: (hostname: string) => boolean): boolean {
  try {
    return predicate(new URL(value).hostname.toLowerCase().replace(/^www\./, ""));
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
