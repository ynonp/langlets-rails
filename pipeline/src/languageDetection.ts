import { generateText } from "ai";
import type { LanguageModel } from "ai";
import { downloadYoutubeAudioToTemp } from "./audio.ts";
import { type SpeechToTextResult, transcribeFileWithElevenLabs } from "./speechToText.ts";
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
    // Detection is also TikTok's transcription step: yt-dlp supplies verified
    // audio and ElevenLabs Scribe returns its detected language plus timed words.
    const audio = await (options.prepareAudio ?? downloadYoutubeAudioToTemp)(payload.youtubeurl);
    let transcript: SpeechToTextResult;
    try {
      transcript = await (options.transcribeFile ?? transcribeFileWithElevenLabs)(audio.path, null);
    } finally {
      await Deno.remove(audio.path).catch(() => {});
    }
    if (!transcript.languageCode) throw new Error("ElevenLabs did not detect a language");
    return {
      language: resolveLanguage(transcript.languageCode, payload.supported_languages),
      data: { lyric_lines: [transcript.text], stt_words: transcript.words },
    };
  }

  throw new Error("unsupported video provider");
}

const ISO_639_3_TO_1: Record<string, string> = {
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
  const base = ISO_639_3_TO_1[raw] ?? raw.split("-")[0];
  const language = supported.find((candidate) =>
    candidate.iso_name.toLowerCase().split("-")[0] === base
  );
  if (!language) throw new Error(`detected unsupported language: ${value.trim() || "unknown"}`);
  return language;
}
