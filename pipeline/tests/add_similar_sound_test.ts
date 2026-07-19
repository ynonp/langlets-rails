import { assert, assertEquals } from "@std/assert";
import { addSimilarSound, buildSimilarSoundLine, tokenize } from "../src/steps/addSimilarSound.ts";
import { Fuzzyword } from "../src/fuzzyword.ts";
import { makeCtx, phrasesFixture } from "./helpers.ts";

// rng that always picks the first option.
const first = () => 0;

const DICT = new Fuzzyword([
  { term: "bonjour", count: 100 },
  { term: "bonjours", count: 50 },
  { term: "salut", count: 80 },
  { term: "salue", count: 40 },
  { term: "monde", count: 60 },
  { term: "monte", count: 30 },
]);

Deno.test("tokenize matches the Ruby String#tokenize extension", () => {
  // Verified against the Ruby regex: an embedded apostrophe stays inside the
  // word, a trailing one becomes its own (too-short, thus ineligible) token.
  assertEquals(tokenize("Don't stop, believin'!"), ["Don't", "stop", "believin", "'"]);
  assertEquals(tokenize("שלום עולם"), ["שלום", "עולם"]);
  assertEquals(tokenize("123 !!"), []);
});

Deno.test("replaces the picked word with a bracketed alternative", () => {
  const line = buildSimilarSoundLine(DICT, "Bonjour le monde", first);
  // first picks "Bonjour" (eligible: Bonjour, monde — "le" is too short),
  // then the nearest alternative "bonjours".
  assertEquals(line, "[bonjours] le monde");
});

Deno.test("lines with no eligible word are skipped", () => {
  assertEquals(buildSimilarSoundLine(DICT, "ah oh no", first), null);
  assertEquals(buildSimilarSoundLine(DICT, "12 34!", first), null);
});

Deno.test("keeps the phrase unchanged when the dictionary has no alternative", () => {
  const line = buildSimilarSoundLine(DICT, "Xylophone et le", first);
  assertEquals(line, "Xylophone et le");
});

Deno.test("no dictionary means every line passes through unchanged", () => {
  assertEquals(buildSimilarSoundLine(null, "Bonjour le monde", first), "Bonjour le monde");
});

Deno.test("addSimilarSound writes one line per phrase into similar_sounds", async () => {
  const { ctx, store } = makeCtx({ data: { phrases: phrasesFixture() } });
  ctx.fuzzywordFor = () => Promise.resolve(DICT);
  ctx.random = first;

  await addSimilarSound(ctx);

  assertEquals(store.data.similar_sounds, "[bonjours] le monde\n[salue] encore");
});

Deno.test("addSimilarSound falls back to pass-through for unsupported languages", async () => {
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    clipLanguage: "Klingon",
  });
  ctx.random = first;
  // No override iso and no built-in mapping → langCodeFor is null and the
  // (never-called) loader must not be reached.
  ctx.fuzzywordFor = () => Promise.reject(new Error("should not load a dictionary"));

  await addSimilarSound(ctx);

  assertEquals(store.data.similar_sounds, "Bonjour le monde\nSalut encore");
});

Deno.test("addSimilarSound records unexpected failures in data.errors", async () => {
  const { ctx, store } = makeCtx({ data: { phrases: phrasesFixture() } });
  ctx.fuzzywordFor = () => Promise.reject(new Error("disk on fire"));

  let threw = false;
  try {
    await addSimilarSound(ctx);
  } catch {
    threw = true;
  }

  assert(threw);
  assertEquals(store.data.errors![0].step, "add_similar_sound");
  assertEquals(store.data.errors![0].error_message, "disk on fire");
});
