// ElevenLabs Speech-to-Text (Scribe), used for TikTok.
//
// Why this exists alongside alignment.ts: the YouTube path is
// *captions + forced alignment* — it already knows the words and only needs
// timings. TikTok posts have no captions worth trusting, so Scribe does both
// jobs at once, returning the transcript *and* per-word timestamps.
//
// The important consequence is that TikTok needs no forced alignment.
// Language detection downloads TikTok's muxed speech candidates and uploads
// them as `file`, then uses `source_url` only after all local candidates fail.
// Later extraction normally reuses that paid result.

import type { AlignedWord } from "./alignment.ts";
import { segmentJapaneseSpeech } from "./japaneseSegmentation.ts";

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

export interface SpeechToTextOptions {
  apiKey?: string;
  fetch?: typeof globalThis.fetch;
}

// Carries the HTTP status so callers can tell a rejected request (400 — TikTok
// blocked the fetch, and the same request will keep being rejected) from a rate
// limit or an outage, which are worth retrying as they are.
export class SpeechToTextRequestError extends Error {
  readonly status: number;

  constructor(status: number, body: string) {
    super(`ElevenLabs speech-to-text failed (${status}): ${body}`);
    this.name = "SpeechToTextRequestError";
    this.status = status;
  }
}

// A successful Scribe request can still contain only music or audio events.
// Keep that outcome distinct so TikTok detection can try another rendition
// without treating authentication, rate-limit, or service errors as content
// selection failures.
export class NoTimedSpeechError extends Error {
  constructor() {
    super("ElevenLabs speech-to-text returned no timed words");
    this.name = "NoTimedSpeechError";
  }
}

export function isNoTimedSpeechError(error: unknown): error is NoTimedSpeechError {
  return error instanceof NoTimedSpeechError;
}

// True when ElevenLabs refused the request itself rather than failing to serve
// it — for a `source_url` submission that means Scribe could not fetch the post,
// so the only way forward is to send the audio bytes.
export function isSpeechToTextRequestRejected(error: unknown): boolean {
  return error instanceof SpeechToTextRequestError && error.status === 400;
}

export function transcribeWithElevenLabs(
  sourceUrl: string,
  languageCode: string | null,
  options: SpeechToTextOptions = {},
): Promise<SpeechToTextResult> {
  return postSpeechToText((form) => form.append("source_url", sourceUrl), languageCode, options);
}

// The fallback form: Scribe reads the uploaded bytes instead of fetching the
// post itself.
export async function transcribeFileWithElevenLabs(
  audioPath: string,
  languageCode: string | null,
  options: SpeechToTextOptions = {},
): Promise<SpeechToTextResult> {
  const bytes = await Deno.readFile(audioPath);
  return await postSpeechToText(
    (form) =>
      form.append(
        "file",
        new Blob([bytes], { type: "audio/mp4" }),
        audioPath.split("/").at(-1) ?? "audio.m4a",
      ),
    languageCode,
    options,
  );
}

async function postSpeechToText(
  appendSource: (form: FormData) => void,
  languageCode: string | null,
  options: SpeechToTextOptions,
): Promise<SpeechToTextResult> {
  const apiKey = options.apiKey ?? Deno.env.get("ELEVEN_LABS_KEY") ??
    Deno.env.get("ELEVENLABS_API_KEY");
  if (!apiKey) throw new Error("ELEVEN_LABS_KEY is not set");

  const form = new FormData();
  form.append("model_id", MODEL_ID);
  appendSource(form);
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
    throw new SpeechToTextRequestError(response.status, body);
  }

  return parseSpeechToText(await response.json(), languageCode);
}

export function parseSpeechToText(
  payload: unknown,
  requestedLanguageCode?: string | null,
): SpeechToTextResult {
  const data = payload as {
    text?: string;
    language_code?: string;
    language_probability?: number;
    words?: RawWord[];
  };

  const code = (data.language_code ?? requestedLanguageCode)?.toLowerCase();
  const japanese = code === "jpn" || code === "ja" || code === "ja-jp";
  const entries: Array<AlignedWord | "space"> = [];
  for (const word of data.words ?? []) {
    if (japanese && word.type === "spacing") {
      entries.push("space");
    } else if (
      word.type === "word" && typeof word.text === "string" && word.text.trim() &&
      Number.isFinite(word.start) && Number.isFinite(word.end)
    ) {
      // Exclude non-speech cues, which collide with the app's bracket markup.
      entries.push({ text: word.text.trim(), start: word.start!, end: word.end! });
    }
  }
  const words = japanese
    ? segmentJapaneseSpeech(entries)
    : entries.filter((entry) => entry !== "space");

  if (words.length === 0) {
    throw new NoTimedSpeechError();
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
