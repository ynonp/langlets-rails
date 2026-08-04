import { assertEquals, assertRejects } from "@std/assert";
import { assertLinesNotEchoed, translate } from "../src/steps/translate.ts";
import {
  initTranslationPayload,
  materializeTranslationLines,
} from "../src/steps/finalizeTranslation.ts";
import { makeCtx, phrasesFixture, queuedModel, unusedModel } from "./helpers.ts";

Deno.test("translate stores lines before the aligned language payload exists", async () => {
  const model = queuedModel(["שלום עולם\nשוב שלום"]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour le monde", "Salut encore"] },
    models: { translate: model.model },
  });

  await translate(ctx);

  assertEquals(store.data.translation_lines!.he, ["שלום עולם", "שוב שלום"]);
  assertEquals(store.data.translations, undefined);
});

Deno.test("translate replaces reserved square brackets", async () => {
  const model = queuedModel(["hello [world]\nbye [again]"]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { translate: model.model },
  });

  await initTranslationPayload(ctx);
  await translate(ctx);
  await materializeTranslationLines(ctx);

  assertEquals(store.data.translations!.he.phrases[0].text, "hello (world)");
});

Deno.test("translate fails on a line-count mismatch and records the response", async () => {
  const model = queuedModel(["only one line"]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { translate: model.model },
  });

  await assertRejects(() => translate(ctx), Error, "line count doesnt match");

  const error = store.data.errors![0];
  assertEquals(error.step, "translate");
  assertEquals(error.agent_response, "only one line");
  assertEquals(store.data.translation_lines, undefined);
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
  const hebrew = queuedModel(["שלום עולם\nשוב שלום"]);
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
  const fallback = queuedModel(["Hello world\nHi again"]);
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
  const model = queuedModel([lines.join("\n")]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: lines },
    models: { translate: model.model },
  });

  await assertRejects(
    () => translate(ctx),
    Error,
    "echo the source language: 8/8 lines came back unchanged",
  );

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
