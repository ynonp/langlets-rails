// Port of app/services/word_timing_parser.rb: turns the word-level
// transcription JSON produced by the extract_lyrics LLM call into the internal
// phrase shape used throughout the Create Song pipeline.
//
// Input (array of line objects):
//   [{ "line_start": "00:00:06,500", "line_end": "00:00:07,800",
//      "line_text": "Apateu, apateu",
//      "words": [{ "word": "Apateu,", "start": "00:00:06,500", "end": "00:00:07,100" }, ...] }]
//
// Output (array of phrase objects):
//   [{ id: "phrase_1", text_l1: "Apateu, apateu",
//      timestamp: "00:06.50", timestamp_end: "00:07.80",
//      words: [{ text: "Apateu,", timestamp: "00:06.50", timestamp_end: "00:07.10",
//                l1_start_index: 0, l1_end_index: 5 }, ...] }]

import type { Phrase, Word } from "./types.ts";
import { secondsToTimestamp, srtToSeconds, timestampToSeconds } from "./timestamps.ts";

interface RawWord {
  word?: string;
  start?: string;
  end?: string;
}

interface RawLine {
  line_start?: string;
  line_end?: string;
  line_text?: string;
  words?: RawWord[];
}

// Accepts either a raw JSON string (legacy free-form LLM text) or an
// already-parsed structure from a structured output call: an Array of line
// objects, or an object wrapping them under "lines".
export function parseWordTimings(input: unknown): Phrase[] {
  const entries = normalizeEntries(input);

  return entries
    .map((entry, idx) => {
      const words: Word[] = (entry.words ?? []).map((w) => ({
        text: sanitize(w.word),
        timestamp: toStringTimestamp(w.start),
        timestamp_end: toStringTimestamp(w.end),
      }));

      const textL1 = entry.line_text?.trim()
        ? sanitize(entry.line_text)
        : words.map((w) => w.text).join(" ");

      assignL1Indices(words, textL1);

      return {
        id: `phrase_${idx + 1}`,
        text_l1: textL1,
        timestamp: toStringTimestamp(entry.line_start),
        timestamp_end: toStringTimestamp(entry.line_end),
        words,
      };
    })
    .filter((phrase) => phrase.text_l1.trim() !== "");
}

// Locate each word inside text_l1 and record its character span as
// l1_start_index / l1_end_index (end is inclusive, matching TokenTranslation's
// character_index convention).
//
// The same word can appear several times in a line ("kissy face, kissy face"),
// so we walk the words in timestamp order, advancing a cursor past each match,
// which guarantees the Nth occurrence in time maps to the Nth occurrence in
// the text. Words that can't be found are left without indices and are skipped
// downstream.
function assignL1Indices(words: Word[], textL1: string): void {
  let cursor = 0;

  const sorted = [...words].sort(
    (a, b) => (timestampSeconds(a.timestamp) ?? 0) - (timestampSeconds(b.timestamp) ?? 0),
  );

  for (const word of sorted) {
    const text = word.text ?? "";
    if (text.trim() === "") continue;

    const span = locateWord(text, textL1, cursor);
    if (!span) continue;

    const [startChar, endChar] = span;
    cursor = endChar + 1;

    word.l1_start_index = startChar;
    word.l1_end_index = endChar;
  }
}

// Find a word inside text_l1 at or after cursor, matching on the word with any
// surrounding punctuation stripped (the token span should cover "symphony"
// rather than "symphony,"). Returns [start, end] (end inclusive) or null.
// Words that are pure punctuation are skipped.
function locateWord(text: string, textL1: string, cursor: number): [number, number] | null {
  const needle = text.replace(/^[\p{P}\p{S}]+|[\p{P}\p{S}]+$/gu, "");
  if (needle === "") return null;

  const idx = textL1.indexOf(needle, cursor);
  return idx >= 0 ? [idx, idx + needle.length - 1] : null;
}

function timestampSeconds(ts: string): number {
  return timestampToSeconds(ts) ?? parseFloat(ts) ?? 0;
}

// The transcript becomes clickable text in the app; square brackets are
// reserved for token-alignment markup, so strip them like the rest of the
// pipeline does.
function sanitize(text: string | undefined): string {
  return (text ?? "").replaceAll("[", "(").replaceAll("]", ")").trim();
}

function normalizeEntries(input: unknown): RawLine[] {
  const data = typeof input === "string" ? JSON.parse(stripCodeFences(input)) : input;

  if (Array.isArray(data)) return data as RawLine[];
  if (data && typeof data === "object") {
    const lines = (data as { lines?: unknown }).lines;
    return Array.isArray(lines) ? (lines as RawLine[]) : [];
  }
  return [];
}

function stripCodeFences(text: string): string {
  return text
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/```\s*$/, "")
    .trim();
}

function toStringTimestamp(srt: string | undefined): string {
  const normalized = (srt ?? "").trim().replaceAll(",", ".");
  const seconds = srtToSeconds(srt) ?? parseFloat(normalized) ?? 0;
  return secondsToTimestamp(Number.isFinite(seconds) ? seconds : 0);
}
