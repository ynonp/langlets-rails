import { assert, assertEquals, assertRejects, assertThrows } from "@std/assert";
import {
  addTokenTranslations,
  buildChunks,
  buildWordLine,
  parseChunkTranslations,
  WORDS_PER_CHUNK,
} from "../src/steps/addTokenTranslations.ts";
import { initTranslationPayload } from "../src/steps/finalizeTranslation.ts";
import { makeCtx, phrasesFixture, queuedModel } from "./helpers.ts";

Deno.test("buildWordLine marks the target word inside its phrase context", () => {
  const phrase = phrasesFixture()[0];
  assertEquals(buildWordLine(phrase, 0), "Bonjour (*Bonjour* monde) |");
  assertEquals(buildWordLine(phrase, 1), "monde (Bonjour *monde*) |");
});

Deno.test("buildChunks packs whole phrases up to the word cap", () => {
  const group = (size: number, tag: number) =>
    Array.from({ length: size }, (_, i) => ({ phraseIndex: tag, wordIndex: i, line: "x |" }));

  const chunks = buildChunks([group(150, 0), group(60, 1), group(30, 2), group(250, 3)]);

  // 150 + 60 > 200 → new chunk; 60 + 30 ≤ 200 → together; 250 alone (over cap).
  assertEquals(chunks.map((c) => c.length), [150, 90, 250]);
  assert(chunks[2].length > WORDS_PER_CHUNK);
});

Deno.test("parseChunkTranslations takes the text after the first pipe, in order", () => {
  const content = [
    "Don't (*Don't* you) | לא",
    "noise line without a pipe",
    "you (Don't *you*) | אתה",
  ].join("\n");

  assertEquals(parseChunkTranslations(content, 2), ["לא", "אתה"]);
});

Deno.test("parseChunkTranslations validates the line count", () => {
  assertThrows(
    () => parseChunkTranslations("a | one", 2),
    Error,
    "Word translation count mismatch: got 1, expected 2",
  );
});

Deno.test("translates every word into the language payload", async () => {
  // 4 words total (2 phrases × 2 words) → one chunk → one call.
  const model = queuedModel(["a | שלום\nb | עולם\nc | היי\nd | עוד"]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { tokenTranslations: model.model },
  });

  await initTranslationPayload(ctx);
  await addTokenTranslations(ctx);

  const payload = store.data.translations!.he;
  assertEquals(payload.phrases[0].words, ["שלום", "עולם"]);
  assertEquals(payload.phrases[1].words, ["היי", "עוד"]);
  assertEquals(model.calls(), 1);
  // The neutral words gained no inline "translation" key.
  // deno-lint-ignore no-explicit-any
  assertEquals((store.data.phrases![0].words[0] as any).translation, undefined);
});

Deno.test("resume skips phrases whose payload words are already complete", async () => {
  // Only phrase_2's two words should be requested.
  const model = queuedModel(["c | היי\nd | עוד"]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { tokenTranslations: model.model },
  });

  await initTranslationPayload(ctx);
  store.data.translations!.he.phrases[0].words = ["שלום", "עולם"];

  await addTokenTranslations(ctx);

  assertEquals(model.calls(), 1);
  assertEquals(store.data.translations!.he.phrases[1].words, ["היי", "עוד"]);
  // Pre-existing translations were left alone.
  assertEquals(store.data.translations!.he.phrases[0].words, ["שלום", "עולם"]);
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
    Array.from({ length: count }, (_, index) => `line${index} | ${translation}`).join("\n");
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
  assertEquals(store.data.translations!.he.phrases[0].words, new Array(150).fill("A"));
  assertEquals(store.data.translations!.he.phrases[1].words, new Array(60).fill("B"));
  assertEquals(store.data.translations!.he.phrases[2].words, new Array(150).fill("A"));
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
  store.data.translations!.he.phrases[1].words = ["שלום", "עולם"];
  await addTokenTranslations(ctx);

  assertEquals(model.calls(), 0);
  assertEquals(store.data.translations!.he.phrases[0].words, ["שלום", "עולם"]);
});

Deno.test("is a no-op when every phrase is already translated", async () => {
  const model = queuedModel([]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { tokenTranslations: model.model },
  });

  await initTranslationPayload(ctx);
  store.data.translations!.he.phrases[0].words = ["שלום", "עולם"];
  store.data.translations!.he.phrases[1].words = ["היי", "עוד"];

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
