import type { Word } from "./types.ts";

// Multi-word expressions that the learner should see and tap as one vocabulary
// item. Keep this language-scoped: spelling and token boundaries are properties
// of the source language, not of the translation language.
export const MULTI_WORD_TOKENS: Record<string, string[]> = {
  en: ["The United States"],
};

const LANGUAGE_CODES: Record<string, string> = {
  english: "en",
  hebrew: "he",
  french: "fr",
  spanish: "es",
  arabic: "ar",
};

type MergeableWord = Word & { sourceFragment?: string; hasSourceTiming?: boolean };

export function mergeMultiWordTokens<T extends MergeableWord>(words: T[], language: string): T[] {
  const entries = dictionaryEntries(language);
  if (entries.length === 0) return words.map((word) => ({ ...word }));

  const merged: T[] = [];
  for (let cursor = 0; cursor < words.length;) {
    const match = entries.find((entry) =>
      entry.parts.every((part, offset) =>
        normalize(words[cursor + offset]?.text ?? "") === normalize(part)
      )
    );
    if (!match) {
      merged.push({ ...words[cursor] });
      cursor += 1;
      continue;
    }

    const group = words.slice(cursor, cursor + match.parts.length);
    const first = group[0];
    const last = group.at(-1)!;
    const sourceFragment = group.every((word) => word.sourceFragment !== undefined)
      ? group.map((word) => word.sourceFragment).join("")
      : undefined;
    merged.push({
      ...first,
      text: match.term,
      timestamp_end: last.timestamp_end ?? first.timestamp_end,
      l1_start_index: undefined,
      l1_end_index: undefined,
      ...(sourceFragment === undefined ? {} : { sourceFragment }),
    });
    cursor += match.parts.length;
  }
  return merged;
}

export function countLearnerTokens(text: string, language: string): number {
  const raw = text.trim().split(/\s+/u).filter(Boolean).map((part) => ({ text: part }));
  return mergeMultiWordTokens(raw, language).length;
}

function dictionaryEntries(language: string) {
  const terms = MULTI_WORD_TOKENS[languageCode(language)] ?? [];
  return terms
    .map((term) => ({ term, parts: term.split(/\s+/u) }))
    .sort((a, b) => b.parts.length - a.parts.length);
}

function languageCode(language: string): string {
  const key = language.toLowerCase().split(/[-_]/)[0];
  return LANGUAGE_CODES[key] ?? key;
}

function normalize(value: string): string {
  return value.normalize("NFC").toLocaleLowerCase().replace(/^[\p{P}\p{S}]+|[\p{P}\p{S}]+$/gu, "");
}

export function capitalizeSentence(text: string): string {
  return text.replace(/\p{L}/u, (letter) => letter.toLocaleUpperCase());
}
