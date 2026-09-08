import { osaDistance, type SoundDictionary } from "./fuzzyword.ts";

export interface ChineseEntry {
  term: string;
  count: number;
  readings: string[];
}

// Entries use numbered pinyin syllables (lv4, not lu4; neutral tone is 5).
// A candidate may change one syllable by one spelling edit and/or its tone.
// Exact homophones are excluded: the learner must be able to hear a difference.
export class ChineseSounds implements SoundDictionary {
  #byWord: Map<string, ChineseEntry>;
  #byLength = new Map<number, ChineseEntry[]>();
  #cache = new Map<string, string[]>();

  constructor(entries: ChineseEntry[]) {
    this.#byWord = new Map(entries.map((entry) => [entry.term, entry]));
    for (const entry of entries) {
      const length = entry.readings[0].split(" ").length;
      const group = this.#byLength.get(length) ?? [];
      group.push(entry);
      this.#byLength.set(length, group);
    }
  }

  lookup(word: string): string[] {
    const cached = this.#cache.get(word);
    if (cached) return cached;
    const source = this.#byWord.get(word);
    // Without sentence-level disambiguation, multiple readings aren't safe.
    if (!source || source.readings.length !== 1) return [];
    const reading = source.readings[0];
    const seenReadings = new Set<string>();
    const candidates = (this.#byLength.get(reading.split(" ").length) ?? [])
      .filter((entry) => entry.term !== word && entry.readings.length === 1)
      .map((entry) => ({ entry, distance: pronunciationDistance(reading, entry.readings[0]) }))
      .filter(({ distance }) => distance > 0 && distance <= 1.25)
      .sort((a, b) =>
        a.distance - b.distance || b.entry.count - a.entry.count ||
        a.entry.term.localeCompare(b.entry.term)
      )
      .filter(({ entry }) => {
        const pronunciation = entry.readings[0];
        if (seenReadings.has(pronunciation)) return false;
        seenReadings.add(pronunciation);
        return true;
      })
      .slice(0, 3)
      .map(({ entry }) => entry.term);
    this.#cache.set(word, candidates);
    return candidates;
  }
}

export function pronunciationDistance(a: string, b: string): number {
  const left = a.split(" ");
  const right = b.split(" ");
  if (left.length !== right.length) return Infinity;
  let distance = 0;
  let changed = 0;
  for (let i = 0; i < left.length; i++) {
    if (left[i] === right[i]) continue;
    if (++changed > 1) return Infinity;
    const spelling = osaDistance(left[i].slice(0, -1), right[i].slice(0, -1), 1);
    if (spelling > 1) return Infinity;
    distance += spelling + (left[i].at(-1) === right[i].at(-1) ? 0 : 0.25);
  }
  return distance;
}
