// Turning a flat stream of timed words into the single provisional phrase the
// rest of the pipeline expects.
//
// Both timing providers converge here. YouTube goes
// captions -> ElevenLabs forced alignment -> words; TikTok goes
// ElevenLabs speech-to-text -> words. From this function on, the two are
// indistinguishable, which is why nothing downstream of force_alignment knows
// TikTok exists.
//
// One phrase, not many, on purpose: provider cue boundaries and performance
// pauses are not semantic lyric lines and routinely split a translation unit in
// the middle. add_lessons re-partitions this continuous stream into
// comprehension lines, reconstructing text and timestamps from these same
// words. See docs/architecture.md.

import type { Phrase } from "./types.ts";
import type { AlignedWord } from "./alignment.ts";
import { parseWordTimings } from "./wordTimingParser.ts";

export function phrasesFromAlignedWords(words: AlignedWord[]): Phrase[] {
  if (words.length === 0) return [];
  return parseWordTimings({ lines: [toRawLine(words)] });
}

export function toRawLine(words: AlignedWord[]) {
  return {
    line_start: secondsToSrt(words[0].start),
    line_end: secondsToSrt(words.at(-1)!.end),
    line_text: words.map((word) => word.text).join(" ").trim(),
    words: words.map((word) => ({
      word: word.text,
      start: secondsToSrt(word.start),
      end: secondsToSrt(word.end),
    })),
  };
}

export function secondsToSrt(seconds: number): string {
  const total = Math.max(0, Math.round(seconds * 1000));
  const hours = Math.floor(total / 3_600_000);
  const minutes = Math.floor((total % 3_600_000) / 60_000);
  const secs = Math.floor((total % 60_000) / 1000);
  const millis = total % 1000;
  const pad = (value: number, length = 2) => String(value).padStart(length, "0");
  return `${pad(hours)}:${pad(minutes)}:${pad(secs)},${pad(millis, 3)}`;
}
