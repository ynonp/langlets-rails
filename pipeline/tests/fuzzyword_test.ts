import { assert, assertEquals } from "@std/assert";
import { dictionaryFor, Fuzzyword, langCodeFor, osaDistance } from "../src/fuzzyword.ts";

Deno.test("osaDistance counts substitutions, insertions, deletions and transpositions", () => {
  assertEquals(osaDistance("house", "house", 2), 0);
  assertEquals(osaDistance("house", "mouse", 2), 1); // substitution
  assertEquals(osaDistance("house", "houses", 2), 1); // insertion
  assertEquals(osaDistance("house", "hose", 2), 1); // deletion
  assertEquals(osaDistance("house", "huose", 2), 1); // transposition = 1 edit (OSA)
  assertEquals(osaDistance("ab", "ba", 2), 1);
});

Deno.test("osaDistance bails out early past the band", () => {
  assertEquals(osaDistance("completely", "different", 2), 3);
});

Deno.test("lookup ranks by distance then frequency and excludes the word itself", () => {
  const dict = new Fuzzyword([
    { term: "house", count: 100 },
    { term: "mouse", count: 500 }, // distance 1
    { term: "horse", count: 900 }, // distance 1, more frequent
    { term: "hose", count: 50 }, // distance 1, least frequent
    { term: "hours", count: 9999 }, // distance 2 — after every distance-1 hit
    { term: "zebra", count: 9999 }, // out of range
  ]);

  assertEquals(dict.lookup("house"), ["horse", "mouse", "hose"]);
});

Deno.test("lookup returns at most three alternatives, ranked by frequency within a distance", () => {
  const dict = new Fuzzyword([
    { term: "cat", count: 10 },
    { term: "cab", count: 20 },
    { term: "car", count: 30 },
    { term: "can", count: 40 },
    { term: "cart", count: 99 }, // insertion → also distance 1
  ]);

  // Four distance-1 candidates → top 3 by frequency.
  assertEquals(dict.lookup("cat"), ["cart", "can", "car"]);
});

Deno.test("lookup is case-insensitive on input and self-exclusion", () => {
  const dict = new Fuzzyword([
    { term: "haus", count: 10 },
    { term: "maus", count: 5 },
  ]);

  assertEquals(dict.lookup("Haus"), ["maus"]);
});

Deno.test("fromText parses 'term count' lines and skips malformed ones", () => {
  const dict = Fuzzyword.fromText("de 4480895281\nla 2669356111\n\nbroken-line\n");
  assertEquals(dict.lookup("de"), ["la"]);
});

Deno.test("langCodeFor maps English names, iso overrides, and region suffixes", () => {
  assertEquals(langCodeFor("French"), "fr");
  assertEquals(langCodeFor("hebrew"), "he");
  assertEquals(langCodeFor("Egyptian Arabic", "ar-EG"), "ar");
  assertEquals(langCodeFor("Levantine", "AR"), "ar");
  // Unknown name, no override → no dictionary.
  assertEquals(langCodeFor("Klingon"), null);
  assertEquals(langCodeFor("Klingon", "tlh"), null);
});

// Parity with the Rust CLI over the real shipped dictionary:
//   $ bin/fuzzyword --lang fr maison
Deno.test("real French dictionary lookup returns close, frequent neighbours", async () => {
  const dict = await dictionaryFor("fr");
  assert(dict, "fr dictionary should load from pipeline/data");

  const alternatives = dict.lookup("maison");
  assertEquals(alternatives.length, 3);
  assert(!alternatives.includes("maison"));
  for (const alt of alternatives) {
    assert(osaDistance("maison", alt, 2) <= 2, `${alt} is not within edit distance 2`);
  }
});
