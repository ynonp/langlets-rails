// Port of CreateSong::AddSimilarSound: for each phrase, replace one random
// word with a similar-sounding dictionary word in [brackets] — the raw
// material for the "spot the wrong word" activity. No LLM involved: the
// alternatives come from a SymSpell-style frequency-dictionary lookup
// (src/fuzzyword.ts, the port of the fuzzyword Rust CLI the Ruby step shelled
// out to).

import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { dictionaryFor, type Fuzzyword, langCodeFor } from "../fuzzyword.ts";

export const MIN_WORD_LENGTH = 3;

export async function addSimilarSound(ctx: PipelineContext): Promise<void> {
  try {
    const code = langCodeFor(ctx.clipLanguage, ctx.clipLanguageIso);
    const dictionary = code ? await (ctx.fuzzywordFor ?? dictionaryFor)(code) : null;
    const random = ctx.random ?? Math.random;

    const results: string[] = [];
    for (const phrase of ctx.store.data.phrases ?? []) {
      const line = buildSimilarSoundLine(dictionary, phrase.text_l1, random);
      if (line !== null) results.push(line);
    }

    await ctx.store.set("similar_sounds", results.join("\n"));
    await clearErrors(ctx, "add_similar_sound");
  } catch (error) {
    await recordError(ctx, "add_similar_sound", error);
    throw error;
  }
}

// Build a line where a random word is replaced with a fuzzyword alternative in
// [brackets]. Returns null when the line has no word long enough to swap, and
// the unchanged phrase when the dictionary offers no alternative — same
// behavior as the Ruby step.
export function buildSimilarSoundLine(
  dictionary: Fuzzyword | null,
  phrase: string,
  random: () => number,
): string | null {
  const words = tokenize(phrase);
  const eligible = words
    .map((word, index) => ({ word, index }))
    .filter(({ word }) => stripTrailingPunctuation(word).length >= MIN_WORD_LENGTH);

  if (eligible.length === 0) return null;

  const pick = eligible[Math.floor(random() * eligible.length)];
  // Separate trailing punctuation from the actual word (the dictionary holds
  // clean words); it is re-attached after the swap.
  const [word, trailing] = splitTrailingPunctuation(pick.word);

  const alternatives = (dictionary?.lookup(word) ?? [])
    .filter((alt) => alt.toLowerCase() !== word.toLowerCase());
  if (alternatives.length === 0) return phrase;

  const alternative = alternatives[Math.floor(random() * alternatives.length)];
  const result = [...words];
  result[pick.index] = `[${alternative}]${trailing}`;
  return result.join(" ");
}

// Port of the String#tokenize core extension: word runs of letters/marks with
// embedded apostrophes.
export function tokenize(text: string): string[] {
  return [...text.matchAll(/['\p{L}][\p{L}\p{M}]*(?:'[\p{L}\p{M}]+)*/gu)].map((m) => m[0]);
}

function stripTrailingPunctuation(word: string): string {
  return word.replace(/\p{P}+$/u, "");
}

// Returns [clean_word, trailing_punctuation].
function splitTrailingPunctuation(word: string): [string, string] {
  const match = word.match(/^(.+?)(\p{P}+)$/u);
  return match ? [match[1], match[2]] : [word, ""];
}
