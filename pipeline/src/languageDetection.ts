import { generateText } from "ai";
import type { LanguageModel } from "ai";
import {
  AUDIO_FORMATS,
  downloadYoutubeAudioToTemp,
  isAudioVerificationUnavailable,
  TIKTOK_SPEECH_FORMATS,
} from "./audio.ts";
import { message } from "./retry.ts";
import {
  isNoTimedSpeechError,
  type SpeechToTextResult,
  transcribeFileWithElevenLabs,
  transcribeWithElevenLabs,
} from "./speechToText.ts";
import { isTiktokUrl, isYoutubeUrl } from "./videoUrl.ts";
import { validateVideoDuration } from "./videoDuration.ts";

export interface SupportedLanguage {
  iso_name: string;
  english_name: string;
}

export interface DetectionPayload {
  youtubeurl: string;
  supported_languages: SupportedLanguage[];
}

export interface DetectionResult {
  language: SupportedLanguage;
  data: Record<string, unknown>;
}

export interface DetectionOptions {
  model: LanguageModel;
  fallbackModel?: LanguageModel;
  validateDuration?: typeof validateVideoDuration;
  prepareAudio?: typeof downloadYoutubeAudioToTemp;
  transcribeFile?: typeof transcribeFileWithElevenLabs;
  transcribeUrl?: typeof transcribeWithElevenLabs;
}

export async function detectLanguage(
  payload: DetectionPayload,
  options: DetectionOptions,
): Promise<DetectionResult> {
  if (payload.supported_languages.length === 0) {
    throw new Error("no supported languages were supplied");
  }

  await (options.validateDuration ?? validateVideoDuration)(payload.youtubeurl);

  const youtube = isYoutubeUrl(payload.youtubeurl);
  if (!youtube && !isTiktokUrl(payload.youtubeurl)) throw new Error("unsupported video provider");

  let transcript: SpeechToTextResult;
  try {
    transcript = youtube
      ? await transcribeYoutube(payload.youtubeurl, options)
      : await transcribeTiktok(payload.youtubeurl, options);
  } catch (error) {
    if (!youtube || isAudioVerificationUnavailable(error)) throw error;
    console.warn(
      `YouTube audio language detection failed (${message(error)}); falling back to Gemini`,
    );
    return { language: await detectYoutubeLanguage(payload, options), data: {} };
  }

  if (!transcript.languageCode) {
    if (youtube) {
      console.warn("Scribe did not detect a language; falling back to Gemini");
      return {
        language: await detectYoutubeLanguage(payload, options),
        data: transcriptCandidate(transcript),
      };
    }
    throw new Error("ElevenLabs did not detect a language");
  }
  return {
    language: resolveLanguage(transcript.languageCode, payload.supported_languages),
    data: transcriptCandidate(transcript),
  };
}

function transcriptCandidate(transcript: SpeechToTextResult): Record<string, unknown> {
  return {
    stt_candidates: {
      elevenlabs: { text: transcript.text, words: transcript.words },
    },
  };
}

async function transcribeYoutube(
  url: string,
  options: DetectionOptions,
): Promise<SpeechToTextResult> {
  const audio = await (options.prepareAudio ?? downloadYoutubeAudioToTemp)(url, AUDIO_FORMATS);
  try {
    return await (options.transcribeFile ?? transcribeFileWithElevenLabs)(audio.path, null);
  } finally {
    await Deno.remove(audio.path).catch(() => {});
  }
}

async function detectYoutubeLanguage(
  payload: DetectionPayload,
  options: DetectionOptions,
): Promise<SupportedLanguage> {
  try {
    return await detectYoutubeLanguageWithModel(payload, options.model);
  } catch (primaryError) {
    if (!options.fallbackModel) throw primaryError;

    console.warn(
      `Gemini 2.5 Flash language detection failed (${message(primaryError)}); ` +
        "falling back to Gemini 3.7 Flash with low thinking",
    );
    try {
      return await detectYoutubeLanguageWithModel(payload, options.fallbackModel, {
        google: { thinkingConfig: { thinkingLevel: "low" } },
      });
    } catch (fallbackError) {
      throw new Error(
        `language detection failed with both Gemini models: ` +
          `2.5 Flash: ${message(primaryError)}; 3.7 Flash: ${message(fallbackError)}`,
        { cause: fallbackError },
      );
    }
  }
}

async function detectYoutubeLanguageWithModel(
  payload: DetectionPayload,
  model: LanguageModel,
  providerOptions?: { google: { thinkingConfig: { thinkingLevel: "low" } } },
): Promise<SupportedLanguage> {
  const allowed = payload.supported_languages.map((language) => language.iso_name).join(", ");
  const { text } = await generateText({
    model,
    system:
      `Detect the primary spoken or sung language in this video. Reply with only one ISO code from this list: ${allowed}. Do not choose a language used only in a short intro or outro.`,
    messages: [{
      role: "user",
      content: [{ type: "file", data: new URL(payload.youtubeurl), mediaType: "video/mp4" }],
    }],
    temperature: 0,
    providerOptions,
  });
  return resolveLanguage(text, payload.supported_languages);
}

// Scribe v2 reports these supported languages as ISO-639-3 while Langlets'
// database uses ISO-639-1 (and may carry a regional suffix such as ar-JO).
const SCRIBE_ISO_639_3_TO_1: Record<string, string> = {
  ara: "ar",
  zho: "zh",
  chi: "zh",
  deu: "de",
  eng: "en",
  ell: "el",
  fra: "fr",
  fre: "fr",
  gre: "el",
  heb: "he",
  spa: "es",
  swe: "sv",
};

export function resolveLanguage(value: string, supported: SupportedLanguage[]): SupportedLanguage {
  const raw = value.trim().toLowerCase().replace(/[^a-z-]/g, "");
  const base = SCRIBE_ISO_639_3_TO_1[raw] ?? raw.split("-")[0];
  const language = supported.find((candidate) =>
    candidate.iso_name.toLowerCase().split("-")[0] === base
  );
  if (!language) throw new Error(`detected unsupported language: ${value.trim() || "unknown"}`);
  return language;
}

async function transcribeTiktok(
  url: string,
  options: DetectionOptions,
): Promise<SpeechToTextResult> {
  const prepareAudio = options.prepareAudio ?? downloadYoutubeAudioToTemp;
  const transcribeFile = options.transcribeFile ?? transcribeFileWithElevenLabs;
  const failures: string[] = [];

  // Each format is downloaded and transcribed separately. An audible track is
  // not necessarily the post's speech track: TikTok's standalone `ba` can be
  // creator music while the muxed video carries the speaker's voice.
  for (const format of TIKTOK_SPEECH_FORMATS) {
    let audio: Awaited<ReturnType<typeof downloadYoutubeAudioToTemp>>;
    try {
      audio = await prepareAudio(url, [format]);
    } catch (error) {
      if (isAudioVerificationUnavailable(error)) throw error;
      failures.push(`${format.format}: ${message(error)}`);
      continue;
    }

    try {
      return await transcribeFile(audio.path, null);
    } catch (error) {
      if (!isNoTimedSpeechError(error)) throw error;
      failures.push(`${format.format}: no timed speech`);
    } finally {
      await Deno.remove(audio.path).catch(() => {});
    }
  }

  // If every local speech candidate was unavailable or contained no words,
  // let ElevenLabs fetch the canonical post URL as the final fallback.
  console.warn(
    `TikTok local speech candidates failed (${failures.join("; ")}); ` +
      "falling back to ElevenLabs URL fetch",
  );
  return await (options.transcribeUrl ?? transcribeWithElevenLabs)(url, null);
}
