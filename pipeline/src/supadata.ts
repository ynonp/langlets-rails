import type { Phrase, Word } from "./types.ts";
import { secondsToTimestamp } from "./timestamps.ts";

const BASE_URL = "https://api.supadata.ai/v1";
const DEFAULT_POLL_INTERVAL_MS = 3_000;
const MAX_POLL_ATTEMPTS = 200;

export interface TranscriptChunk {
  text: string;
  offset: number;
  duration: number;
  lang: string;
}

export interface TranscriptResult {
  content: TranscriptChunk[];
  lang: string;
  availableLangs: string[];
}

interface TranscriptJob {
  jobId: string;
}

interface TranscriptJobResult extends Partial<TranscriptResult> {
  status: "queued" | "active" | "completed" | "failed";
  error?: unknown;
}

export interface SupadataOptions {
  apiKey?: string;
  fetch?: typeof globalThis.fetch;
  pollIntervalMs?: number;
  sleep?: (ms: number) => Promise<void>;
}

export const MAX_LINE_LENGTH = 42;

export function transcriptToText(chunks: TranscriptChunk[]): string {
  return chunks.map((chunk) => cleanTranscriptText(chunk.text)).filter(Boolean).join(" ").trim();
}

export function transcriptToLines(chunks: TranscriptChunk[]): string[] {
  return chunks.flatMap((chunk) => {
    // Native captions commonly include non-speech cues such as [Music],
    // [Música], and [Applause]. Square brackets are also reserved by the app's
    // token markup, so these annotations are not learning content.
    const text = cleanTranscriptText(chunk.text);
    if (!text) return [];
    const sentences = text.match(/.*?(?:[.!?。！？]+(?=\s|$)|$)/gu)
      ?.map((part) => part.trim()).filter(Boolean) ?? [];
    return sentences.flatMap((sentence) => splitLongLine(sentence));
  });
}

// Music videos are the common case here, and YouTube's caption tracks for them
// wrap every line in ♪ … ♪. Those are whitespace-separated tokens like any
// other, so left in they become "words": counted by force_alignment, handed to
// add_lessons as index slots, and sent to add_token_translations, which under
// its punctuation rule answers "♪" — a clickable vocabulary item with a musical
// note in it.
const NON_SPEECH_SYMBOLS = /[♪♫♬♩𝅗𝅥𝅘𝅥𝅮]/gu;

function cleanTranscriptText(text: string): string {
  return text
    .replace(/\[[^\]\r\n]*\]/gu, " ")
    .replace(NON_SPEECH_SYMBOLS, " ")
    .replace(/\s+/gu, " ")
    .trim();
}

// Supadata's `lang` parameter is a preference, not a filter: when the requested
// track does not exist it returns whichever one does. A Japanese subtitle track
// on an English song is a perfectly well-formed response, and taking it builds
// a course whose lyrics are a translation of the song. Compare on the primary
// subtag so "en" and "en-US" agree.
export function isSameLanguage(a: string, b: string): boolean {
  return primarySubtag(a) === primarySubtag(b);
}

function primarySubtag(code: string): string {
  return code.trim().toLowerCase().split(/[-_]/u)[0];
}

function splitLongLine(text: string): string[] {
  const lines: string[] = [];
  let rest = text.trim();
  while ([...rest].length > MAX_LINE_LENGTH) {
    const chars = [...rest];
    const prefix = chars.slice(0, MAX_LINE_LENGTH + 1);
    const comma = Math.max(prefix.lastIndexOf(","), prefix.lastIndexOf("،"));
    let whitespace = -1;
    for (let index = 1; index <= MAX_LINE_LENGTH; index++) {
      if (/\s/u.test(prefix[index])) whitespace = index;
    }
    const cut = comma >= 0 ? comma + 1 : whitespace > 0 ? whitespace : MAX_LINE_LENGTH;
    lines.push(chars.slice(0, cut).join("").trim());
    rest = chars.slice(cut).join("").trim();
  }
  if (rest) lines.push(rest);
  return lines;
}

export async function transcribeWithSupadata(
  videoUrl: string,
  languageCode: string | null,
  options: SupadataOptions = {},
): Promise<TranscriptResult> {
  const apiKey = options.apiKey ?? Deno.env.get("SUPADATA_KEY") ??
    Deno.env.get("SUPADATA_API_KEY");
  if (!apiKey) throw new Error("SUPADATA_KEY is not set");

  const request = options.fetch ?? globalThis.fetch;
  const url = new URL(`${BASE_URL}/transcript`);
  url.searchParams.set("url", videoUrl);
  url.searchParams.set("text", "false");
  url.searchParams.set("mode", "native");
  if (languageCode) url.searchParams.set("lang", languageCode);

  const response = await request(url, { headers: { "x-api-key": apiKey } });
  const body = await readJson(response);
  if (!response.ok) throw apiError("transcription", response.status, body);

  if (response.status !== 202 && !isJob(body)) return validateResult(body);
  if (!isJob(body)) throw new Error("Supadata returned 202 without a jobId");

  return await pollTranscript(body.jobId, apiKey, options);
}

async function pollTranscript(
  jobId: string,
  apiKey: string,
  options: SupadataOptions,
): Promise<TranscriptResult> {
  const request = options.fetch ?? globalThis.fetch;
  const sleep = options.sleep ??
    ((ms: number) => new Promise((resolve) => setTimeout(resolve, ms)));
  const interval = options.pollIntervalMs ?? DEFAULT_POLL_INTERVAL_MS;

  for (let attempt = 0; attempt < MAX_POLL_ATTEMPTS; attempt++) {
    if (attempt > 0) await sleep(interval);
    const response = await request(`${BASE_URL}/transcript/${encodeURIComponent(jobId)}`, {
      headers: { "x-api-key": apiKey },
    });
    const body = await readJson(response) as TranscriptJobResult;
    if (!response.ok) throw apiError("job polling", response.status, body);
    if (body.status === "completed") return validateResult(body);
    if (body.status === "failed") {
      throw new Error(`Supadata transcription job failed: ${errorText(body.error)}`);
    }
    if (body.status !== "queued" && body.status !== "active") {
      throw new Error(`Supadata transcription job returned invalid status: ${String(body.status)}`);
    }
  }

  throw new Error(`Supadata transcription job ${jobId} did not finish`);
}

export function transcriptToPhrases(chunks: TranscriptChunk[]): Phrase[] {
  return chunks.flatMap((chunk, index) => {
    const text = chunk.text.trim();
    if (!text) return [];
    const start = Math.max(0, chunk.offset / 1000);
    const end = Math.max(start, (chunk.offset + chunk.duration) / 1000);
    const words = interpolateWordTimings(text, start, end);
    if (words.length === 0) return [];

    return [{
      id: `phrase_${index + 1}`,
      text_l1: text,
      timestamp: secondsToTimestamp(start),
      timestamp_end: secondsToTimestamp(end),
      words,
    }];
  });
}

// Supadata timestamps transcript chunks, not individual words. Distribute the
// chunk duration by character width so downstream players retain their
// word-level timing contract without another alignment provider.
function interpolateWordTimings(text: string, start: number, end: number): Word[] {
  const matches = [...text.matchAll(/\S+/gu)];
  const totalWeight = matches.reduce((sum, match) => sum + match[0].length, 0);
  const duration = Math.max(0, end - start);
  let elapsedWeight = 0;

  return matches.map((match) => {
    const wordStart = start + duration * elapsedWeight / totalWeight;
    elapsedWeight += match[0].length;
    const wordEnd = start + duration * elapsedWeight / totalWeight;
    const l1Start = match.index!;
    return {
      text: match[0],
      timestamp: secondsToTimestamp(wordStart),
      timestamp_end: secondsToTimestamp(wordEnd),
      l1_start_index: l1Start,
      l1_end_index: l1Start + match[0].length,
    };
  });
}

async function readJson(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`Supadata returned invalid JSON (${response.status}): ${text}`);
  }
}

function validateResult(value: unknown): TranscriptResult {
  const result = value as Partial<TranscriptResult>;
  if (!Array.isArray(result?.content)) {
    throw new Error("Supadata returned no timestamped transcript");
  }
  const content = result.content.filter((chunk) =>
    typeof chunk?.text === "string" && Number.isFinite(chunk?.offset) &&
    Number.isFinite(chunk?.duration)
  );
  if (content.length === 0) throw new Error("Supadata returned an empty transcript");
  return {
    content,
    lang: typeof result.lang === "string" ? result.lang : content[0].lang,
    availableLangs: Array.isArray(result.availableLangs) ? result.availableLangs : [],
  };
}

function isJob(value: unknown): value is TranscriptJob {
  return typeof (value as TranscriptJob)?.jobId === "string";
}

function apiError(action: string, status: number, body: unknown): Error {
  return new Error(`Supadata ${action} failed (${status}): ${errorText(body)}`);
}

function errorText(value: unknown): string {
  if (typeof value === "string") return value;
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}
