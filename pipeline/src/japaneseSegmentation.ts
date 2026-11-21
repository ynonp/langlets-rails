import type { AlignedWord } from "./alignment.ts";

const segmenter = new Intl.Segmenter("ja", { granularity: "word" });

function segments(text: string): Array<{ text: string; start: number; end: number }> {
  const tokens: Array<{ text: string; start: number; end: number }> = [];
  for (const { segment, index, isWordLike } of segmenter.segment(text)) {
    if (/^\s+$/u.test(segment)) continue;
    const end = index + segment.length;
    const previous = tokens.at(-1);
    if (!isWordLike && /^[、。！？!?…」』）】]+$/u.test(segment) && previous) {
      previous.text += segment;
      previous.end = end;
    } else {
      tokens.push({ text: segment, start: index, end });
    }
  }
  return tokens;
}

export function segmentJapaneseCaption(text: string): string {
  return segments(text).map((token) => token.text).join(" ");
}

// Scribe emits Japanese as timed characters. Keep their timing at the
// segment edges and preserve provider spacing in mixed-script passages.
export function segmentJapaneseSpeech(entries: Array<AlignedWord | "space">): AlignedWord[] {
  const timings: Array<{ start: number; end: number } | undefined> = [];
  let text = "";
  for (const entry of entries) {
    if (entry === "space") {
      timings.push(undefined);
      text += " ";
      continue;
    }

    text += entry.text;
    const duration = Math.max(0, entry.end - entry.start);
    const characters = [...entry.text];
    characters.forEach((character, index) => {
      const timing = {
        start: entry.start + duration * index / characters.length,
        end: entry.start + duration * (index + 1) / characters.length,
      };
      for (let unit = 0; unit < character.length; unit++) timings.push(timing);
    });
  }

  return segments(text).map((token) => ({
    text: token.text,
    start: timings[token.start]!.start,
    end: timings[token.end - 1]!.end,
  }));
}
