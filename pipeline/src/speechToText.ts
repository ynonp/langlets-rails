// ElevenLabs Speech-to-Text (Scribe), used for TikTok.
//
// Why this exists alongside alignment.ts: the YouTube path is
// *captions + forced alignment* — it already knows the words and only needs
// timings. TikTok posts have no captions worth trusting, so Scribe does both
// jobs at once, returning the transcript *and* per-word timestamps.
//
// The important consequence is that TikTok needs no forced alignment and no
// audio download. `source_url` accepts a TikTok URL directly, so yt-dlp never
// runs — which also means the TikTok path has no dependency on
// YTDLP_NETWORK_NAMESPACE or on a working yt-dlp extractor.

import type { AlignedWord } from "./alignment.ts";

const BASE_URL = "https://api.elevenlabs.io";
const MODEL_ID = "scribe_v2";

export interface SpeechToTextResult {
  text: string;
  words: AlignedWord[];
  languageCode: string | null;
  languageProbability: number | null;
}

interface RawWord {
  text?: string;
  start?: number;
  end?: number;
  // "word" is speech; "spacing" is the gap between words; "audio_event" is a
  // non-speech cue such as [cantando] or [Applause].
  type?: string;
  logprob?: number;
}

export async function transcribeWithElevenLabs(
  sourceUrl: string,
  languageCode: string | null,
  options: { apiKey?: string; fetch?: typeof globalThis.fetch } = {},
): Promise<SpeechToTextResult> {
  const apiKey = options.apiKey ?? Deno.env.get("ELEVEN_LABS_KEY") ??
    Deno.env.get("ELEVENLABS_API_KEY");
  if (!apiKey) throw new Error("ELEVEN_LABS_KEY is not set");

  const form = new FormData();
  form.append("model_id", MODEL_ID);
  form.append("source_url", sourceUrl);
  form.append("timestamps_granularity", "word");
  // Diarization would split the transcript by speaker, which the phrase model
  // has no use for and which costs extra.
  form.append("diarize", "false");
  if (languageCode) form.append("language_code", languageCode);

  const response = await (options.fetch ?? globalThis.fetch)(`${BASE_URL}/v1/speech-to-text`, {
    method: "POST",
    headers: { "xi-api-key": apiKey },
    body: form,
  });
  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(`ElevenLabs speech-to-text failed (${response.status}): ${body}`);
  }

  return parseSpeechToText(await response.json());
}

export function parseSpeechToText(payload: unknown): SpeechToTextResult {
  const data = payload as {
    text?: string;
    language_code?: string;
    language_probability?: number;
    words?: RawWord[];
  };

  const words = (data.words ?? [])
    // Keep speech only. Dropping audio_event here is what removes "[cantando]"
    // and friends: they aren't learning content, and square brackets are
    // reserved by the app's token markup — the same rule the native-caption
    // path applies in supadata.ts.
    .filter((word) =>
      word.type === "word" && typeof word.text === "string" &&
      word.text.trim() !== "" && Number.isFinite(word.start) && Number.isFinite(word.end)
    )
    .map((word) => ({
      text: word.text!.trim(),
      start: word.start!,
      end: word.end!,
    }));

  if (words.length === 0) {
    throw new Error("ElevenLabs speech-to-text returned no timed words");
  }

  return {
    // Rebuilt from the kept words rather than taken from data.text, which still
    // contains the audio events we just dropped. The transcript and the timed
    // words must describe exactly the same thing — add_lessons partitions one
    // by word count and reconstructs the other from it.
    text: words.map((word) => word.text).join(" "),
    words,
    languageCode: data.language_code ?? null,
    languageProbability: typeof data.language_probability === "number"
      ? data.language_probability
      : null,
  };
}
