import { assertEquals, assertRejects } from "@std/assert";
import { parseRatings, rateLessons } from "../src/steps/rateLessons.ts";
import { makeCtx, queuedModel, unusedModel } from "./helpers.ts";

const RATINGS_JSON = JSON.stringify([
  { index: 1, title: "The Golden Dream", score: 5, reason: "Varied vocabulary." },
  { index: 2, title: "The Apateu Chant", score: 1, reason: "One word chanted." },
]);

Deno.test("parseRatings reads a bare JSON array", () => {
  const ratings = parseRatings(RATINGS_JSON);
  assertEquals(ratings.length, 2);
  assertEquals(ratings[0], {
    index: 1,
    title: "The Golden Dream",
    score: 5,
    reason: "Varied vocabulary.",
  });
});

Deno.test("parseRatings tolerates markdown fences and surrounding prose", () => {
  const ratings = parseRatings("Here you go:\n```json\n" + RATINGS_JSON + "\n```\nDone!");
  assertEquals(ratings.length, 2);
  assertEquals(ratings[1].score, 1);
});

Deno.test("parseRatings returns empty for garbage", () => {
  assertEquals(parseRatings("no json here"), []);
  assertEquals(parseRatings("[not, valid json"), []);
});

Deno.test("rateLessons stores parsed ratings", async () => {
  const model = queuedModel([RATINGS_JSON]);
  const { ctx, store } = makeCtx({
    data: { lessons: "# The Golden Dream\nWe were good\n\n# The Apateu Chant\nApateu apateu" },
    models: { rateLessons: model.model },
  });

  await rateLessons(ctx);

  assertEquals(store.data.lesson_ratings!.length, 2);
  assertEquals(store.data.lesson_ratings![0].title, "The Golden Dream");
  assertEquals(model.calls(), 1);
});

Deno.test("rateLessons is a no-op without lessons", async () => {
  const model = unusedModel();
  const { ctx, store } = makeCtx({ models: { rateLessons: model.model } });

  await rateLessons(ctx);

  assertEquals(model.calls(), 0);
  assertEquals(store.data.lesson_ratings, undefined);
});

Deno.test("rateLessons retries unparsable output and records the response on failure", async () => {
  const responses = Array(6).fill("I refuse to answer in JSON");
  const model = queuedModel(responses);
  const { ctx, store } = makeCtx({
    data: { lessons: "# A lesson\nline" },
    models: { rateLessons: model.model },
  });

  await assertRejects(() => rateLessons(ctx), Error, "No ratings parsed");
  assertEquals(model.calls(), 6);

  const error = store.data.errors![0];
  assertEquals(error.step, "rate_lessons");
  assertEquals(error.agent_response, "I refuse to answer in JSON");
});
