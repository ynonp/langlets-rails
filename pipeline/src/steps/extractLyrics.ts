import { generateObject } from "ai";
import { z } from "zod";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { geminiTimedTranscriptPrompt } from "../prompts/geminiTimedTranscript.ts";
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
import { reconcileTimedTranscript } from "../reconcileTimedTranscript.ts";
import { isYoutubeUrl } from "../videoUrl.ts";
import { phrasesFromAlignedWords } from "../alignedWords.ts";
import type { DownloadedAudio } from "../audio.ts";

const MAX_GEMINI_RETRIES = 2;
const MAX_STT_RETRIES = 2;
const MAX_AUDIO_RETRIES = 2;
const MAX_RECONCILIATION_RETRIES = 1;

const reconciliationSchema = z.object({ transcript: z.string().min(1) });
const timedTranscriptSchema = z.object({
  words: z.array(z.object({
    word: z.string().min(1),
    start_seconds: z.number().nonnegative(),
    end_seconds: z.number().nonnegative(),
  })).min(1),
});

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

    if (isYoutubeUrl(ctx.youtubeurl) && !store.data.stt_candidates?.elevenlabs) {
      let audio: DownloadedAudio;
      try {
        audio = await prepareAudio(ctx);
      } catch (error) {
        if (isAudioVerificationUnavailable(error)) throw error;
        console.warn(
          `ExtractLyrics yt-dlp failed; using Gemini timed transcription: ${message(error)}`,
        );
        const words = await geminiTimedFallback(
          ctx,
          (text) => lastResponseText = text,
          (attempt) => attempts = Math.max(attempts, attempt),
        );
        await persistTimedGeminiTranscript(ctx, words);
        await clearErrors(ctx, "extract_lyrics");
        await clearErrors(ctx, "force_alignment");
        return;
      }

      try {
        const jobs: Promise<unknown>[] = [];
        if (!store.data.stt_candidates?.supadata) {
          jobs.push(captureSupadata(ctx, languageCode));
        }
        jobs.push(captureElevenLabsFromAudio(ctx, audio, languageCode, (attempt) => {
          attempts = Math.max(attempts, attempt);
        }));
        await settleCandidates(jobs);
      } finally {
        await Deno.remove(audio.path).catch(() => {});
      }
    } else {
      const jobs: Promise<unknown>[] = [];
      if (!store.data.stt_candidates?.supadata) {
        jobs.push(captureSupadata(ctx, languageCode));
      }
      if (!store.data.stt_candidates?.elevenlabs) {
        jobs.push(captureElevenLabs(ctx, languageCode, (attempt) => {
          attempts = Math.max(attempts, attempt);
        }));
      }
      await settleCandidates(jobs);
    }

    const supadata = store.data.stt_candidates?.supadata;
    const elevenlabs = store.data.stt_candidates?.elevenlabs;
    let transcriptText: string;
    let sttWords: SpeechToTextResult["words"] = [];

    if (supadata && elevenlabs) {
      try {
        const reconciledText = await withRetries(
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
        const reconciliation = reconcileTimedTranscript(reconciledText, elevenlabs.words);
        sttWords = reconciliation.words;
        transcriptText = sttWords.map((word) => word.text).join(" ");
        if (reconciliation.fallbackSpans > 0) {
          console.warn(
            `Transcript reconciliation retained ElevenLabs wording for ` +
              `${reconciliation.fallbackSpans} unsafe span(s)`,
          );
        }
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
      const words = await geminiTimedFallback(
        ctx,
        (text) => lastResponseText = text,
        (attempt) => attempts = Math.max(attempts, attempt),
      );
      await persistTimedGeminiTranscript(ctx, words);
      await clearErrors(ctx, "extract_lyrics");
      await clearErrors(ctx, "force_alignment");
      return;
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

async function settleCandidates(jobs: Promise<unknown>[]): Promise<void> {
  const results = await Promise.allSettled(jobs);
  for (const result of results) {
    if (result.status === "rejected") {
      console.warn(`STT candidate failed: ${message(result.reason)}`);
    }
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
  const audio = await prepareAudio(ctx);
  try {
    await captureElevenLabsFromAudio(ctx, audio, languageCode, onAttempt);
  } finally {
    await Deno.remove(audio.path).catch(() => {});
  }
}

function prepareAudio(ctx: PipelineContext): Promise<DownloadedAudio> {
  return withRetries(
    () => (ctx.prepareAudio ?? downloadYoutubeAudioToTemp)(ctx.youtubeurl),
    {
      maxRetries: MAX_AUDIO_RETRIES,
      label: "ExtractLyrics audio",
      baseDelayMs: ctx.baseDelayMs,
      isFatal: isAudioVerificationUnavailable,
    },
  );
}

async function captureElevenLabsFromAudio(
  ctx: PipelineContext,
  audio: DownloadedAudio,
  languageCode: string | null,
  onAttempt: (attempt: number) => void,
): Promise<void> {
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
}

async function geminiTimedFallback(
  ctx: PipelineContext,
  onResponse: (text: string) => void,
  onAttempt: (attempt: number) => void,
): Promise<SpeechToTextResult["words"]> {
  console.warn("ExtractLyrics falling back to Gemini timed transcription");
  return await withRetries(async () => {
    const result = await generateObject({
      model: ctx.models.extractLyrics,
      schema: timedTranscriptSchema,
      system: geminiTimedTranscriptPrompt(ctx.clipLanguage),
      messages: [{
        role: "user",
        content: [{ type: "file", data: new URL(ctx.youtubeurl), mediaType: "video/mp4" }],
      }],
    });
    onResponse(JSON.stringify(result.object));
    return validateTimedGeminiWords(result.object.words);
  }, {
    maxRetries: MAX_GEMINI_RETRIES,
    label: "ExtractLyrics Gemini",
    baseDelayMs: ctx.baseDelayMs,
    onFailedAttempt: (_error, attempt) => onAttempt(attempt),
  });
}

function validateTimedGeminiWords(
  returned: z.infer<typeof timedTranscriptSchema>["words"],
): SpeechToTextResult["words"] {
  let previousStart = 0;
  const words = returned.flatMap((entry, index) => {
    const text = cleanupTranscript(entry.word.trim());
    if (
      !Number.isFinite(entry.start_seconds) || !Number.isFinite(entry.end_seconds) ||
      entry.end_seconds < entry.start_seconds || entry.start_seconds < previousStart
    ) {
      throw new Error(`Gemini returned invalid timestamps for transcript word ${index + 1}`);
    }
    previousStart = entry.start_seconds;
    if (!text) return [];
    if (/\s/u.test(text)) {
      throw new Error(`Gemini merged multiple transcript words in entry ${index + 1}`);
    }
    return [{ text, start: entry.start_seconds, end: entry.end_seconds }];
  });
  if (words.length === 0) throw new Error("Gemini returned no usable timed words");
  return words;
}

async function persistTimedGeminiTranscript(
  ctx: PipelineContext,
  words: SpeechToTextResult["words"],
): Promise<void> {
  const phrases = phrasesFromAlignedWords(words);
  if (phrases.length !== 1) throw new Error("Gemini returned no usable timed transcript");
  await ctx.store.patch([
    { op: "set", path: "lyric_lines", value: [phrases[0].text_l1] },
    { op: "set", path: "stt_words", value: words },
    { op: "set", path: "transcription_source", value: "gemini" },
    { op: "set", path: "phrases", value: phrases },
    { op: "set", path: "video_length_seconds", value: words.at(-1)!.end },
    { op: "set", path: "extract_lyrics_in_progress", value: false },
    { op: "set", path: "force_alignment_in_progress", value: false },
  ]);
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
