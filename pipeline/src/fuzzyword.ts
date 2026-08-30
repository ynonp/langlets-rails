// TypeScript port of the fuzzyword Rust CLI (activities/fuzzyword — a thin
// wrapper around symspell_rs). Given a word, return up to MAX_RESULTS
// dictionary words within edit distance MAX_EDIT_DISTANCE, ordered like
// SymSpell's Verbosity::All: by edit distance first, then by term frequency —
// excluding the word itself.
//
// The lookup here is a linear scan with a banded distance computation instead
// of SymSpell's delete-index. That trades per-lookup speed for zero index
// build time, which is the right trade for our access pattern: one lookup per
// phrase (~50-100 per song) against dictionaries of ≤100k entries.
//
// Distance is OSA (optimal string alignment: Levenshtein + adjacent
// transposition counted as one edit), matching symspell_rs's default.

const MAX_EDIT_DISTANCE = 2;
const MAX_RESULTS = 3;

// Same catalog as the Rust CLI's LANGS table. Dictionary lines are
// "term count", most frequent first.
const DICTIONARIES: Record<string, string> = {
  en: "frequency_dictionary_en_82_765.txt",
  fr: "fr-100k.txt",
  de: "de-100k.txt",
  he: "he-100k.txt",
  ru: "ru-100k.txt",
  es: "es-100k.txt",
  ar: "ar-50k.txt",
};

// clip_language arrives as an English name (the Rails Language.english_name);
// AddSimilarSound resolved it to an iso code through the DB. Without a DB we
// map the supported names statically, and the trigger payload can override
// with an explicit clip_language_iso for anything else.
const ENGLISH_NAMES: Record<string, string> = {
  english: "en",
  french: "fr",
  german: "de",
  greek: "el",
  hebrew: "he",
  russian: "ru",
  spanish: "es",
  swedish: "sv",
  arabic: "ar",
};

// Resolve a clip language to a bare iso code, preferring an explicit iso
// override. Region suffixes are stripped ("ar-JO" → "ar") like the Ruby
// fuzzyword_lang_code did. Returns null when the language is unknown.
export function isoCodeFor(clipLanguage: string, iso?: string | null): string | null {
  const code = (iso ?? ENGLISH_NAMES[clipLanguage.trim().toLowerCase()] ?? "")
    .split("-")[0]
    .toLowerCase();
  return code || null;
}

// Resolve the fuzzyword language code for a clip language: an iso code that
// also has a similar-sound dictionary. Returns null when no dictionary exists.
export function langCodeFor(clipLanguage: string, iso?: string | null): string | null {
  const code = isoCodeFor(clipLanguage, iso);
  return code && code in DICTIONARIES ? code : null;
}

interface DictEntry {
  term: string;
  count: number;
}

export class Fuzzyword {
  #entries: DictEntry[];

  constructor(entries: DictEntry[]) {
    this.#entries = entries;
  }

  static fromText(text: string): Fuzzyword {
    const entries: DictEntry[] = [];
    for (const line of text.split("\n")) {
      const sep = line.indexOf(" ");
      if (sep <= 0) continue;
      const term = line.slice(0, sep);
      const count = Number(line.slice(sep + 1));
      entries.push({ term, count: Number.isFinite(count) ? count : 0 });
    }
    return new Fuzzyword(entries);
  }

  // Up to MAX_RESULTS alternatives for `word`, nearest first (ties broken by
  // frequency), never including the word itself.
  lookup(word: string): string[] {
    const needle = word.toLowerCase();
    const candidates: Array<DictEntry & { dist: number }> = [];

    for (const entry of this.#entries) {
      if (Math.abs(entry.term.length - needle.length) > MAX_EDIT_DISTANCE) continue;
      const dist = osaDistance(needle, entry.term, MAX_EDIT_DISTANCE);
      if (dist <= MAX_EDIT_DISTANCE) candidates.push({ ...entry, dist });
    }

    return candidates
      .sort((a, b) => a.dist - b.dist || b.count - a.count)
      .filter((c) => c.term.toLowerCase() !== needle)
      .slice(0, MAX_RESULTS)
      .map((c) => c.term);
  }
}

// One dictionary per language, loaded once per isolate. The promise is cached
// (not the result) so concurrent first lookups share a single load.
const cache = new Map<string, Promise<Fuzzyword | null>>();

export function dictionaryFor(code: string): Promise<Fuzzyword | null> {
  let loading = cache.get(code);
  if (!loading) {
    loading = loadDictionary(code);
    cache.set(code, loading);
  }
  return loading;
}

async function loadDictionary(code: string): Promise<Fuzzyword | null> {
  const file = DICTIONARIES[code];
  if (!file) return null;

  try {
    const text = await Deno.readTextFile(new URL(`../data/${file}`, import.meta.url));
    return Fuzzyword.fromText(text);
  } catch (error) {
    console.warn(`fuzzyword: failed to load ${file}: ${error}`);
    return null;
  }
}

// Banded OSA distance between a and b; returns max + 1 as soon as the
// distance provably exceeds `max`, so the scan can discard most entries after
// a row or two.
export function osaDistance(a: string, b: string, max: number): number {
  if (a === b) return 0;

  let prevPrev: number[] = [];
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j);

  for (let i = 1; i <= a.length; i++) {
    const current = [i];
    let rowMin = i;

    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      let value = Math.min(
        prev[j] + 1, // deletion
        current[j - 1] + 1, // insertion
        prev[j - 1] + cost, // substitution
      );
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        value = Math.min(value, prevPrev[j - 2] + 1); // transposition
      }
      current.push(value);
      if (value < rowMin) rowMin = value;
    }

    if (rowMin > max) return max + 1;
    prevPrev = prev;
    prev = current;
  }

  return prev[b.length];
}
