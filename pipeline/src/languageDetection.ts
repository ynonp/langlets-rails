import { generateText } from "ai";
import type { LanguageModel } from "ai";
import { downloadYoutubeAudioToTemp } from "./audio.ts";
import { message } from "./retry.ts";
import {
  type SpeechToTextResult,
  transcribeFileWithElevenLabs,
  transcribeWithElevenLabs,
} from "./speechToText.ts";
import { isTiktokUrl, isYoutubeUrl } from "./steps/extractLyrics.ts";

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

  if (isYoutubeUrl(payload.youtubeurl)) {
    const allowed = payload.supported_languages.map((language) => language.iso_name).join(", ");
    const { text } = await generateText({
      model: options.model,
      system:
        `Detect the primary spoken or sung language in this video. Reply with only one ISO code from this list: ${allowed}. Do not choose a language used only in a short intro or outro.`,
      messages: [{
        role: "user",
        content: [{ type: "file", data: new URL(payload.youtubeurl), mediaType: "video/mp4" }],
      }],
      temperature: 0,
    });
    return { language: resolveLanguage(text, payload.supported_languages), data: {} };
  }

  if (isTiktokUrl(payload.youtubeurl)) {
    const transcript = await transcribeTiktok(payload.youtubeurl, options);
    if (!transcript.languageCode) throw new Error("ElevenLabs did not detect a language");
    return {
      language: resolveLanguage(transcript.languageCode, payload.supported_languages),
      data: {
        stt_candidates: {
          elevenlabs: { text: transcript.text, words: transcript.words },
        },
      },
    };
  }

  throw new Error("unsupported video provider");
}

// Scribe v2 reports these supported languages as ISO-639-3 while Langlets'
// database uses ISO-639-1 (and may carry a regional suffix such as ar-JO).
const SCRIBE_ISO_639_3_TO_1: Record<string, string> = {
  ara: "ar",
  deu: "de",
  eng: "en",
  fra: "fr",
  fre: "fr",
  heb: "he",
  spa: "es",
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
  let audio: Awaited<ReturnType<typeof downloadYoutubeAudioToTemp>>;
  try {
    // Downloading ourselves is the cheaper path and lets us reject silent or
    // audio-less TikTok renditions before paying ElevenLabs to process them.
    audio = await (options.prepareAudio ?? downloadYoutubeAudioToTemp)(url);
  } catch (error) {
    // If every yt-dlp format/namespace failed, let ElevenLabs fetch the TikTok
    // URL itself. This costs more, so it is deliberately the second choice.
    console.warn(
      `TikTok audio download failed (${message(error)}); falling back to ElevenLabs URL fetch`,
    );
    return await (options.transcribeUrl ?? transcribeWithElevenLabs)(url, null);
  }

  try {
    return await (options.transcribeFile ?? transcribeFileWithElevenLabs)(audio.path, null);
  } finally {
    await Deno.remove(audio.path).catch(() => {});
  }
}
