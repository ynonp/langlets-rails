import { assertEquals, assertRejects } from "@std/assert";
import { translate } from "../src/steps/translate.ts";
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
