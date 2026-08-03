import { generateObject, generateText } from "ai";
import { z } from "zod";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { extractLyricsPrompt } from "../prompts/extractLyrics.ts";
import { reconcileTranscriptsPrompt } from "../prompts/reconcileTranscripts.ts";
import { message, withRetries } from "../retry.ts";
import {
  isSameLanguage,
  transcribeWithSupadata,
  type TranscriptResult,
  transcriptToText,
} from "../supadata.ts";
import { type SpeechToTextResult, transcribeFileWithElevenLabs } from "../speechToText.ts";
import { downloadYoutubeAudioToTemp, isAudioVerificationUnavailable } from "../audio.ts";
import { cleanupTranscript } from "../cleanupTranscript.ts";

const MAX_GEMINI_RETRIES = 2;
const MAX_STT_RETRIES = 2;
const MAX_AUDIO_RETRIES = 2;
const MAX_RECONCILIATION_RETRIES = 1;

const reconciliationSchema = z.object({ transcript: z.string().min(1) });

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

    const jobs: Promise<unknown>[] = [];
    if (!store.data.stt_candidates?.supadata) {
      jobs.push(captureSupadata(ctx, languageCode));
    }
    if (!store.data.stt_candidates?.elevenlabs) {
      jobs.push(captureElevenLabs(ctx, languageCode, (attempt) => {
        attempts = Math.max(attempts, attempt);
      }));
    }
    const results = await Promise.allSettled(jobs);
    for (const result of results) {
      if (result.status === "rejected") {
        console.warn(`STT candidate failed: ${message(result.reason)}`);
      }
    }

    const supadata = store.data.stt_candidates?.supadata;
    const elevenlabs = store.data.stt_candidates?.elevenlabs;
    let transcriptText: string;
    let sttWords: SpeechToTextResult["words"] = [];

    if (supadata && elevenlabs) {
      try {
        transcriptText = await withRetries(
          async () => {
            const result = await generateObject({
              model: ctx.models.reconcileTranscripts,
              schema: reconciliationSchema,
              system: reconcileTranscriptsPrompt(ctx.clipLanguage),
              prompt: `SUPADATA:\n${supadata.text}\n\nELEVENLABS:\n${elevenlabs.text}`,
              temperature: 0,
              providerOptions: { openai: { reasoningEffort: "none" } },
            });
            lastResponseText = JSON.stringify(result.object);
            const cleaned = cleanupTranscript(result.object.transcript);
            if (!cleaned) throw new Error("Sol reconciliation returned no usable transcript");
            return cleaned;
          },
          {
            maxRetries: MAX_RECONCILIATION_RETRIES,
            label: "ExtractLyrics Sol reconciliation",
            baseDelayMs: ctx.baseDelayMs,
          },
        );
      } catch (error) {
        console.warn(`Transcript reconciliation failed; using ElevenLabs: ${message(error)}`);
        transcriptText = cleanupTranscript(elevenlabs.text);
        sttWords = elevenlabs.words;
      }
    } else if (elevenlabs) {
      transcriptText = cleanupTranscript(elevenlabs.text);
      sttWords = elevenlabs.words;
    } else if (supadata) {
      transcriptText = cleanupTranscript(supadata.text);
    } else if (isYoutubeUrl(ctx.youtubeurl)) {
      transcriptText = await geminiFallback(ctx, (text) => lastResponseText = text, (attempt) => {
        attempts = Math.max(attempts, attempt);
      });
    } else {
      throw new Error("Supadata and ElevenLabs transcription both failed");
    }

    if (!transcriptText) throw new Error("Transcription produced no usable text");
    await store.patch([
      { op: "set", path: "lyric_lines", value: [transcriptText] },
      { op: "set", path: "stt_words", value: sttWords },
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

async function captureSupadata(ctx: PipelineContext, languageCode: string | null): Promise<void> {
  const transcript = await (ctx.transcribeVideo ?? transcribeWithSupadata)(
    ctx.youtubeurl,
    languageCode,
  );
  assertTranscriptLanguage(transcript, languageCode, ctx.clipLanguage);
  const text = transcriptToText(transcript.content);
  if (!text) throw new Error("Supadata returned no usable native transcript");
  await ctx.store.set("stt_candidates.supadata", { text });
}

async function captureElevenLabs(
  ctx: PipelineContext,
  languageCode: string | null,
  onAttempt: (attempt: number) => void,
): Promise<void> {
  const audio = await withRetries(
    () => (ctx.prepareAudio ?? downloadYoutubeAudioToTemp)(ctx.youtubeurl),
    {
      maxRetries: MAX_AUDIO_RETRIES,
      label: "ExtractLyrics audio",
      baseDelayMs: ctx.baseDelayMs,
      isFatal: isAudioVerificationUnavailable,
    },
  );
  try {
    const result = await withRetries(
      () => (ctx.transcribeSpeechFile ?? transcribeFileWithElevenLabs)(audio.path, languageCode),
      {
        maxRetries: MAX_STT_RETRIES,
        label: "ExtractLyrics ElevenLabs speech-to-text (uploaded audio)",
        baseDelayMs: ctx.baseDelayMs,
        onFailedAttempt: (_error, attempt) => onAttempt(attempt),
      },
    );
    await ctx.store.set("stt_candidates.elevenlabs", {
      text: result.text,
      words: result.words,
    });
  } finally {
    await Deno.remove(audio.path).catch(() => {});
  }
}

async function geminiFallback(
  ctx: PipelineContext,
  onResponse: (text: string) => void,
  onAttempt: (attempt: number) => void,
): Promise<string> {
  console.warn("ExtractLyrics falling back to Gemini after both STT providers failed");
  return await withRetries(async () => {
    const { text } = await generateText({
      model: ctx.models.extractLyrics,
      system: extractLyricsPrompt(ctx.clipLanguage),
      messages: [{
        role: "user",
        content: [{ type: "file", data: new URL(ctx.youtubeurl), mediaType: "video/mp4" }],
      }],
      temperature: 0,
    });
    onResponse(text);
    const cleaned = cleanupTranscript(parseLyricsLines(text).join(" "));
    if (!cleaned) throw new Error("Gemini lyrics response contained no usable text");
    return cleaned;
  }, {
    maxRetries: MAX_GEMINI_RETRIES,
    label: "ExtractLyrics Gemini",
    baseDelayMs: ctx.baseDelayMs,
    onFailedAttempt: (_error, attempt) => onAttempt(attempt),
  });
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

// The caption track Supadata hands back is not necessarily the one we asked
// for, and accepting the wrong one is not a transcription failure that shows up
// as a failure — it is a course whose lyrics are a translation of the song,
// which then breaks force_alignment (foreign text over the real audio) two
// steps later with a message about word counts. Reject it here, where the
// existing catch falls back to Gemini, which reads the audio itself and is told
// the clip language.
export function assertTranscriptLanguage(
  transcript: TranscriptResult,
  requested: string | null,
  clipLanguage: string,
): void {
  if (!requested) {
    // No ISO code means no `lang` on the request either, so Supadata was free to
    // pick any track. Nothing to compare against — say so rather than pretend
    // the transcript was verified.
    console.warn(
      `ExtractLyrics has no transcription language code for ${clipLanguage}; ` +
        `Supadata chose the caption track (got ${transcript.lang || "unknown"})`,
    );
    return;
  }
  if (transcript.lang && !isSameLanguage(transcript.lang, requested)) {
    throw new Error(
      `Supadata returned a ${transcript.lang} transcript for a ${requested} clip` +
        (transcript.availableLangs.length > 0
          ? ` (available: ${transcript.availableLangs.join(", ")})`
          : ""),
    );
  }
}
