import { assert, assertEquals, assertRejects, assertThrows } from "@std/assert";
import {
  addTokenTranslations,
  assertNotEchoed,
  buildChunks,
  buildWordLine,
  LINES_PER_CHUNK,
  parseChunkTranslations,
} from "../src/steps/addTokenTranslations.ts";
import { initTranslationPayload } from "../src/steps/finalizeTranslation.ts";
import {
  addTokenTranslationsPrompt,
  examples,
  legacyAddTokenTranslationsPrompt,
} from "../src/prompts/addTokenTranslations.ts";
import { makeCtx, phrasesFixture, queuedModel } from "./helpers.ts";

Deno.test("token translation prompt selects its example by target language", () => {
  const frenchPrompt = addTokenTranslationsPrompt("Spanish", "French");
  const hebrewPrompt = addTokenTranslationsPrompt("Spanish", "Hebrew");

  assert(frenchPrompt.includes(`## Expected Output:\n${examples.French}`));
  assert(!frenchPrompt.includes(examples.Hebrew));
  assert(hebrewPrompt.includes(`## Expected Output:\n${examples.Hebrew}`));
});

Deno.test("token translation prompt adds only the narrow scope guard to legacy", () => {
  const prompt = addTokenTranslationsPrompt("English", "Hebrew");
  const legacy = legacyAddTokenTranslationsPrompt("English", "Hebrew");

  assert(prompt.includes("Translate only the marked word"));
  assert(!legacy.includes("Translate only the marked word"));
  assert(!prompt.includes("standalone learner gloss"));
  assert(prompt.includes("most natural Hebrew translation"));
});

Deno.test("token translation prompt omits examples for an unknown target language", () => {
  const prompt = addTokenTranslationsPrompt("Spanish", "Italian");

  assert(!prompt.includes("## Example Input:"));
  assert(!prompt.includes("## Expected Output:"));
});

Deno.test("buildWordLine marks the target word inside its phrase context", () => {
  const phrase = phrasesFixture()[0];
  assertEquals(buildWordLine(phrase, 0), "Bonjour (*Bonjour* monde) |");
  assertEquals(buildWordLine(phrase, 1), "monde (Bonjour *monde*) |");
});

Deno.test("buildChunks packs whole phrases up to the word cap", () => {
  const group = (size: number, tag: number) =>
    Array.from({ length: size }, (_, i) => ({
      phraseIndex: tag,
      wordIndex: i,
      text: "x",
      line: "x |",
    }));

  const chunks = buildChunks([group(80, 0), group(30, 1), group(20, 2), group(125, 3)]);

  // 80 + 30 > 100 → new chunk; 30 + 20 ≤ 100 → together; 125 alone (over cap).
  assertEquals(chunks.map((c) => c.length), [80, 50, 125]);
  assert(chunks[2].length > LINES_PER_CHUNK);
});

Deno.test("parseChunkTranslations takes the text after the first pipe, in order", () => {
  const content = [
    "Don't (*Don't* you) | לא [auxiliary]",
    "noise line without a pipe",
    "you (Don't *you*) | אתה [pronoun]",
  ].join("\n");

  assertEquals(parseChunkTranslations(content, 2), ["לא [auxiliary]", "אתה [pronoun]"]);
});

Deno.test("parseChunkTranslations validates the line count", () => {
  assertThrows(
    () => parseChunkTranslations("a | one", 2),
    Error,
    "Word translation count mismatch: got 1, expected 2",
  );
});

Deno.test("parseChunkTranslations requires a supported part of speech", () => {
  assertThrows(
    () => parseChunkTranslations("a | one", 1),
    Error,
    "Missing or invalid part of speech",
  );
});

Deno.test("assertNotEchoed rejects a chunk that came back in the source language", () => {
  // The real failure: gemini-3.5-flash-lite repeating each Arabic word with a
  // plausible part of speech instead of translating it.
  const words = ["الدكتور", "حسام", "الفاضل", "يعني", "اريد", "ان", "اذكره", "بشيء", "اول", "شيء"];

  assertThrows(
    () => assertNotEchoed(words, words.map((w) => `${w} [noun]`)),
    Error,
    "echo the source language: 10/10 words came back unchanged",
  );
});

Deno.test("assertNotEchoed allows the echo a correct translation contains", () => {
  // Proper names, numerals and punctuation come back unchanged when the
  // translation is right, and a cognate ("hotel") genuinely translates to
  // itself. None of that is the failure this guards against.
  const words = [
    "voy",
    "a",
    "Madrid",
    "en",
    "el",
    "hotel",
    "número",
    "7",
    ",",
    "ahora",
    "mismo",
    "con",
    "mi",
    "hermana",
  ];
  const translations = [
    "I go [verb]",
    "to [preposition]",
    "Madrid [proper_noun]",
    "in [preposition]",
    "the [determiner]",
    "hotel [noun]",
    "number [noun]",
    "7 [numeral]",
    ", [punctuation]",
    "right [adverb]",
    "now [adverb]",
    "with [preposition]",
    "my [determiner]",
    "sister [noun]",
  ];

  assertNotEchoed(words, translations);
});

Deno.test("assertNotEchoed ignores a chunk too small to judge", () => {
  // Four words of nothing but names is a plausible short clip, not a bad run.
  const words = ["Hossam", "Al-Fadel", "Gaza", "Israel"];

  assertNotEchoed(words, words.map((w) => `${w} [proper_noun]`));
});

Deno.test("an echoed chunk is retried and then recorded as a failure", async () => {
  const phrases = [{
    id: "phrase_1",
    text_l1: "",
    timestamp: "00:00.00",
    timestamp_end: "00:10.00",
    words: Array.from({ length: 10 }, (_, index) => ({
      text: `كلمة${index}`,
      timestamp: "00:00.00",
      timestamp_end: "00:01.00",
    })),
  }];
  const echo = Array.from({ length: 10 }, (_, index) => `x | كلمة${index} [noun]`).join("\n");
  const model = queuedModel([echo, echo, echo]);
  const { ctx, store } = makeCtx({
    data: { phrases },
    models: { tokenTranslations: model.model },
  });

  await initTranslationPayload(ctx);
  await assertRejects(() => addTokenTranslations(ctx), Error, "echo the source language");
  assertEquals(model.calls(), 3);

  // Nothing was written: an echoed chunk leaves the phrase untranslated for a
  // later run rather than filling it with source-language words.
  assertEquals(store.data.translations!.he.phrases[0].words, new Array(10).fill(null));
  assertEquals(store.data.errors![0].step, "add_token_translations");
});

Deno.test("translates every word into the language payload", async () => {
  // 4 words total (2 phrases × 2 words) → one chunk → one call.
  const model = queuedModel([
    "a | שלום [noun]\nb | עולם [noun]\nc | היי [interjection]\nd | עוד [adverb]",
  ]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { tokenTranslations: model.model },
  });

  await initTranslationPayload(ctx);
  await addTokenTranslations(ctx);

  const payload = store.data.translations!.he;
  assertEquals(payload.phrases[0].words, ["שלום [noun]", "עולם [noun]"]);
  assertEquals(payload.phrases[1].words, ["היי [interjection]", "עוד [adverb]"]);
  assertEquals(model.calls(), 1);
  // The neutral words gained no inline "translation" key.
  // deno-lint-ignore no-explicit-any
  assertEquals((store.data.phrases![0].words[0] as any).translation, undefined);
});

Deno.test("resume skips phrases whose payload words are already complete", async () => {
  // Only phrase_2's two words should be requested.
  const model = queuedModel(["c | היי [interjection]\nd | עוד [adverb]"]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { tokenTranslations: model.model },
  });

  await initTranslationPayload(ctx);
  store.data.translations!.he.phrases[0].words = ["שלום [noun]", "עולם [noun]"];

  await addTokenTranslations(ctx);

  assertEquals(model.calls(), 1);
  assertEquals(store.data.translations!.he.phrases[1].words, [
    "היי [interjection]",
    "עוד [adverb]",
  ]);
  // Pre-existing translations were left alone.
  assertEquals(store.data.translations!.he.phrases[0].words, ["שלום [noun]", "עולם [noun]"]);
});

Deno.test("deduplicates identical phrases globally before building chunks", async () => {
  const phrase = (id: string, prefix: string, count: number) => ({
    id,
    text_l1: prefix,
    timestamp: "00:00.00",
    timestamp_end: "00:10.00",
    words: Array.from({ length: count }, (_, index) => ({
      text: `${prefix}${index}`,
      timestamp: "00:00.00",
      timestamp_end: "00:01.00",
    })),
  });
  const repeated = phrase("phrase_1", "a", 150);
  const phrases = [
    repeated,
    phrase("phrase_2", "b", 60),
    { ...structuredClone(repeated), id: "phrase_3" },
  ];
  const response = (count: number, translation: string) =>
    Array.from({ length: count }, (_, index) => `line${index} | ${translation} [noun]`).join("\n");
  const model = queuedModel([response(150, "A"), response(60, "B")]);
  const { ctx, store } = makeCtx({
    data: { phrases },
    models: { tokenTranslations: model.model },
  });

  await initTranslationPayload(ctx);
  await addTokenTranslations(ctx);

  // Without global pre-batch deduplication these sizes produce three chunks:
  // [150], [60], [150]. The repeated final phrase must reuse the first result.
  assertEquals(model.calls(), 2);
  assertEquals(store.data.translations!.he.phrases[0].words, new Array(150).fill("A [noun]"));
  assertEquals(store.data.translations!.he.phrases[1].words, new Array(60).fill("B [noun]"));
  assertEquals(store.data.translations!.he.phrases[2].words, new Array(150).fill("A [noun]"));
});

Deno.test("resume reuses a completed identical phrase without an LLM call", async () => {
  const phrases = phrasesFixture();
  phrases[1] = { ...structuredClone(phrases[0]), id: "phrase_2" };
  const model = queuedModel([]);
  const { ctx, store } = makeCtx({
    data: { phrases },
    models: { tokenTranslations: model.model },
  });

  await initTranslationPayload(ctx);
  store.data.translations!.he.phrases[1].words = ["שלום [noun]", "עולם [noun]"];
  await addTokenTranslations(ctx);

  assertEquals(model.calls(), 0);
  assertEquals(store.data.translations!.he.phrases[0].words, ["שלום [noun]", "עולם [noun]"]);
});

Deno.test("is a no-op when every phrase is already translated", async () => {
  const model = queuedModel([]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { tokenTranslations: model.model },
  });

  await initTranslationPayload(ctx);
  store.data.translations!.he.phrases[0].words = ["שלום [noun]", "עולם [noun]"];
  store.data.translations!.he.phrases[1].words = ["היי [interjection]", "עוד [adverb]"];

  await addTokenTranslations(ctx);
  assertEquals(model.calls(), 0);
});

Deno.test("a failed chunk records its input lines and the raw LLM response", async () => {
  // 3 attempts (1 + 2 retries), every response is one line short.
  const model = queuedModel(["a | x", "a | x", "a | x"]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { tokenTranslations: model.model },
  });

  await initTranslationPayload(ctx);
  await assertRejects(() => addTokenTranslations(ctx), Error, "count mismatch");
  assertEquals(model.calls(), 3);

  const error = store.data.errors![0];
  assertEquals(error.step, "add_token_translations");
  assertEquals(error.attempts, 3);
  assertEquals(error.input_lines, [
    "Bonjour (*Bonjour* monde) |",
    "monde (Bonjour *monde*) |",
    "Salut (*Salut* encore) |",
    "encore (Salut *encore*) |",
  ]);
  assertEquals(error.agent_response, "a | x");
});
