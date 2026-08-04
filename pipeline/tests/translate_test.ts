import { assertEquals, assertRejects, assertStringIncludes } from "@std/assert";
import {
  assertLinesNotEchoed,
  buildChunks,
  LINES_PER_CHUNK,
  parseNumberedLines,
  translate,
} from "../src/steps/translate.ts";
import {
  initTranslationPayload,
  materializeTranslationLines,
} from "../src/steps/finalizeTranslation.ts";
import { makeCtx, phrasesFixture, queuedModel, unusedModel } from "./helpers.ts";

// The mock records the message array each call received; the instructions ride
// on it as the system message.
function promptText(prompt: unknown): string {
  return JSON.stringify(prompt);
}

Deno.test("translate stores lines before the aligned language payload exists", async () => {
  const model = queuedModel(["1. שלום עולם\n2. שוב שלום"]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour le monde", "Salut encore"] },
    models: { translate: model.model },
  });

  await translate(ctx);

  assertEquals(store.data.translation_lines!.he, ["שלום עולם", "שוב שלום"]);
  assertEquals(store.data.translations, undefined);
});

Deno.test("translate replaces reserved square brackets", async () => {
  const model = queuedModel(["1. hello [world]\n2. bye [again]"]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { translate: model.model },
  });

  await initTranslationPayload(ctx);
  await translate(ctx);
  await materializeTranslationLines(ctx);

  assertEquals(store.data.translations!.he.phrases[0].text, "hello (world)");
});

Deno.test("translate repairs a merged line by asking again for just that number", async () => {
  // The real failure this guards against: the model merges two neighbouring
  // fragment lines into the one natural clause they make together. Line 3
  // never comes back, and without numbers there is no way to say which.
  const model = queuedModel([
    "1. Hello world\n2. And everything that\n4. Everything in his life",
    "3. That",
  ]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour le monde", "Et tout", "Ce qui", "Toute sa vie"] },
    models: { translate: model.model },
  });

  await translate(ctx);

  assertEquals(model.calls(), 2);
  assertEquals(store.data.translation_lines!.he, [
    "Hello world",
    "And everything that",
    "That",
    "Everything in his life",
  ]);

  // The repair pass names the gap and still carries the whole chunk as context.
  const repair = promptText(model.prompts[1]);
  assertStringIncludes(repair, "input line numbers, in this order: 3");
  assertStringIncludes(repair, "4. Toute sa vie");
  assertEquals(store.data.errors, undefined);
});

Deno.test("translate fails with the missing line numbers once the attempts are spent", async () => {
  const model = queuedModel([
    "1. Hello world",
    "1. Hello world",
    "1. Hello world",
  ]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { translate: model.model },
  });

  await assertRejects(() => translate(ctx), Error, "1 of 2 lines missing after 3 attempts: 2");

  const error = store.data.errors![0];
  assertEquals(error.step, "translate");
  assertEquals(error.attempts, 3);
  assertEquals(error.agent_response, "1. Hello world");
  assertEquals(error.input_lines, ["Bonjour le monde", "Salut encore"]);
  assertEquals(store.data.translation_lines, undefined);
});

Deno.test("translate never asks for a blank source line", async () => {
  const model = queuedModel(["1. Hello world\n3. Hi again"]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour le monde", "  ", "Salut encore"] },
    models: { translate: model.model },
  });

  await translate(ctx);

  assertEquals(model.calls(), 1);
  assertEquals(store.data.translation_lines!.he, ["Hello world", "  ", "Hi again"]);
  // A blank line has no translation to ask for, so the request names the two
  // that do rather than claiming three lines are wanted.
  assertStringIncludes(promptText(model.prompts[0]), "input line numbers, in this order: 1, 3");
});

Deno.test("translate ignores commentary and out-of-range numbers in the response", async () => {
  const model = queuedModel([
    "Here is the translation:\n\n1. Hello world\n7. Not asked for\n2. Hi again\n2. Duplicate",
  ]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { translate: model.model },
  });

  await translate(ctx);

  assertEquals(store.data.translation_lines!.he, ["Hello world", "Hi again"]);
});

Deno.test("translate chunks long transcripts and numbers them globally", async () => {
  const lyricLines = Array.from({ length: LINES_PER_CHUNK + 3 }, (_, i) => `Ligne ${i + 1}`);
  const answer = (from: number, to: number) =>
    Array.from({ length: to - from + 1 }, (_, i) => `${from + i}. Line ${from + i}`).join("\n");
  const model = queuedModel([
    answer(1, LINES_PER_CHUNK),
    answer(LINES_PER_CHUNK + 1, LINES_PER_CHUNK + 3),
  ]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: lyricLines },
    models: { translate: model.model },
  });

  await translate(ctx);

  assertEquals(model.calls(), 2);
  assertEquals(store.data.translation_lines!.he.length, LINES_PER_CHUNK + 3);
  // The second chunk keeps the whole transcript's numbering rather than
  // restarting at 1 — a line number identifies a line, everywhere.
  assertEquals(store.data.translation_lines!.he.at(-1), `Line ${LINES_PER_CHUNK + 3}`);
});

Deno.test("buildChunks packs lines in order up to the cap", () => {
  const sourceLines = Array.from({ length: LINES_PER_CHUNK + 1 }, (_, i) => ({
    number: i + 1,
    text: `Ligne ${i + 1}`,
  }));

  const chunks = buildChunks(sourceLines);

  assertEquals(chunks.length, 2);
  assertEquals(chunks[0].length, LINES_PER_CHUNK);
  assertEquals(chunks[1], [{ number: LINES_PER_CHUNK + 1, text: `Ligne ${LINES_PER_CHUNK + 1}` }]);
});

Deno.test("parseNumberedLines keeps the first answer for each requested number", () => {
  const requested = [1, 2, 3].map((number) => ({ number, text: `Ligne ${number}` }));

  const parsed = parseNumberedLines(
    "1) First\n2. \n2 - Second\n3: Third\n9. Unrequested\nunnumbered",
    requested,
  );

  assertEquals([...parsed], [[1, "First"], [2, "Second"], [3, "Third"]]);
});

Deno.test("materializeTranslationLines copies saved lines into aligned phrase slots", async () => {
  const { ctx, store } = makeCtx({
    data: {
      phrases: phrasesFixture(),
      translation_lines: { he: ["שלום עולם", "שוב שלום"] },
    },
  });

  await initTranslationPayload(ctx);
  await materializeTranslationLines(ctx);

  assertEquals(store.data.translations!.he.phrases[0].text, "שלום עולם");
  assertEquals(store.data.translations!.he.phrases[1].text, "שוב שלום");
});

Deno.test("materializeTranslationLines skips lyric lines dropped by alignment", async () => {
  const phrases = phrasesFixture();
  const { ctx, store } = makeCtx({
    data: {
      lyric_lines: ["Bonjour le monde", "Untimed line", "Salut encore"],
      phrases,
      translation_lines: { he: ["שלום עולם", "ללא זמן", "שוב שלום"] },
    },
  });

  await initTranslationPayload(ctx);
  await materializeTranslationLines(ctx);

  assertEquals(store.data.translations!.he.phrases.map((phrase) => phrase.text), [
    "שלום עולם",
    "שוב שלום",
  ]);
});

Deno.test("materializeTranslationLines matches bracket-sanitized aligned phrases", async () => {
  const { ctx, store } = makeCtx({
    data: {
      lyric_lines: ["[Música]"],
      phrases: [{
        id: "phrase_1",
        text_l1: "(Música)",
        timestamp: "00:01.00",
        timestamp_end: "00:02.00",
        words: [],
      }],
      translation_lines: { he: ["(Music)"] },
    },
  });

  await initTranslationPayload(ctx);
  await materializeTranslationLines(ctx);

  assertEquals(store.data.translations!.he.phrases[0].text, "(Music)");
});

Deno.test("materialization failures are recorded as translation errors", async () => {
  const { ctx, store } = makeCtx({
    data: {
      lyric_lines: ["Different line"],
      phrases: phrasesFixture().slice(0, 1),
      translation_lines: { he: ["תרגום"] },
    },
  });

  await initTranslationPayload(ctx);
  await assertRejects(() => materializeTranslationLines(ctx), Error, "Could not match");

  assertEquals(store.data.errors?.[0].step, "translate");
});

Deno.test("translate uses the per-language model when the registry has one", async () => {
  const hebrew = queuedModel(["1. שלום עולם\n2. שוב שלום"]);
  const fallback = unusedModel();
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour le monde", "Salut encore"] },
    models: { translate: fallback.model, translateOverrides: { he: hebrew.model } },
  });

  await translate(ctx);

  assertEquals(hebrew.calls(), 1);
  assertEquals(fallback.calls(), 0);
  assertEquals(store.data.translation_lines!.he, ["שלום עולם", "שוב שלום"]);
});

Deno.test("translate falls back to the default model for other languages", async () => {
  const hebrew = unusedModel();
  const fallback = queuedModel(["1. Hello world\n2. Hi again"]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour le monde", "Salut encore"] },
    models: { translate: fallback.model, translateOverrides: { he: hebrew.model } },
    translationLanguage: { id: 1, iso_name: "en", english_name: "English" },
  });

  await translate(ctx);

  assertEquals(fallback.calls(), 1);
  assertEquals(hebrew.calls(), 0);
  assertEquals(store.data.translation_lines!.en, ["Hello world", "Hi again"]);
});

Deno.test("translate fails when the response echoes the source lines", async () => {
  // The real failure this guards against: the model repeats the Arabic
  // source back instead of translating it into Hebrew, and nothing else
  // catches it because the line count matches.
  const lines = [
    "الدكتور حسام",
    "الفاضل يعني",
    "اريد ان",
    "اذكره بشيء",
    "اول شيء",
    "في هذا",
    "الوقت بالذات",
    "شكرا جزيلا",
  ];
  const echoed = lines.map((line, index) => `${index + 1}. ${line}`).join("\n");
  // Echo is a misunderstood task rather than a partial answer, so the whole
  // response is dropped and every attempt asks again for all eight lines.
  const model = queuedModel([echoed, echoed, echoed]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: lines },
    models: { translate: model.model },
  });

  await assertRejects(
    () => translate(ctx),
    Error,
    "echo the source language: 8/8 lines came back unchanged",
  );

  assertEquals(model.calls(), 3);

  const error = store.data.errors![0];
  assertEquals(error.step, "translate");
  assertEquals(store.data.translation_lines, undefined);
});

Deno.test("assertLinesNotEchoed allows a real translation that happens to share a line", () => {
  // A cognate or a proper name translating to itself is not the failure —
  // only a response that echoes wholesale is.
  const source = [
    "Bonjour le monde",
    "Salut encore",
    "Comment ça va",
    "Je vais bien",
    "Merci beaucoup",
    "À plus tard",
    "Hotel",
    "Au revoir",
  ];
  const translated = [
    "Hello world",
    "Hi again",
    "How are you",
    "I am well",
    "Thank you",
    "See you later",
    "Hotel",
    "Goodbye",
  ];

  assertLinesNotEchoed(source, translated);
});

Deno.test("assertLinesNotEchoed ignores a clip too short to judge", () => {
  const lines = ["Bonjour", "Salut", "Merci"];

  assertLinesNotEchoed(lines, lines);
});

Deno.test("translate is a no-op without a target language", async () => {
  const model = unusedModel();
  const { ctx } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { translate: model.model },
    translationLanguage: null,
  });

  await translate(ctx);
  assertEquals(model.calls(), 0);
});
