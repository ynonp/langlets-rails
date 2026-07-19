import { assertEquals, assertRejects } from "@std/assert";
import { translate } from "../src/steps/translate.ts";
import { initTranslationPayload } from "../src/steps/finalizeTranslation.ts";
import { makeCtx, phrasesFixture, queuedModel, unusedModel } from "./helpers.ts";

Deno.test("translate writes each line into the language payload", async () => {
  const model = queuedModel(["שלום עולם\nשוב שלום"]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { translate: model.model },
  });

  await initTranslationPayload(ctx);
  await translate(ctx);

  const payload = store.data.translations!.he;
  assertEquals(payload.phrases[0].text, "שלום עולם");
  assertEquals(payload.phrases[1].text, "שוב שלום");
  // The neutral phrases stay untouched — no inline text_l2.
  // deno-lint-ignore no-explicit-any
  assertEquals((store.data.phrases![0] as any).text_l2, undefined);
});

Deno.test("translate replaces reserved square brackets", async () => {
  const model = queuedModel(["hello [world]\nbye [again]"]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { translate: model.model },
  });

  await initTranslationPayload(ctx);
  await translate(ctx);

  assertEquals(store.data.translations!.he.phrases[0].text, "hello (world)");
});

Deno.test("translate fails on a line-count mismatch and records the response", async () => {
  const model = queuedModel(["only one line"]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { translate: model.model },
  });

  await initTranslationPayload(ctx);
  await assertRejects(() => translate(ctx), Error, "line count doesnt match");

  const error = store.data.errors![0];
  assertEquals(error.step, "translate");
  assertEquals(error.agent_response, "only one line");
  // Nothing was written to the payload.
  assertEquals(store.data.translations!.he.phrases[0].text, null);
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
