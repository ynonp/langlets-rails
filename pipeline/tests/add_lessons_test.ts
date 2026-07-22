import { assert, assertEquals, assertRejects } from "@std/assert";
import {
  addLessons,
  matchLessonDataToPrompt,
  materializeLessons,
} from "../src/steps/addLessons.ts";
import { makeCtx, phrasesFixture, queuedModel } from "./helpers.ts";

Deno.test("matchLessonDataToPrompt rebuilds lessons from our own clip lines", () => {
  const clipLines = [
    "00:05.00 We were good",
    "00:06.00 we were gold",
    "00:07.00 I didn't wanna leave you",
    "00:08.00 I didn't wanna lie",
  ].join("\n");

  const llmResponse = [
    "# The Golden Dream",
    "We were good",
    "we were gold",
    "",
    "# The Turning Point",
    "I didn't wanna leave you",
    "I didn't wanna lie",
  ].join("\n");

  const result = matchLessonDataToPrompt(clipLines, llmResponse);

  assertEquals(
    result,
    [
      "# The Golden Dream",
      "00:05.00 We were good",
      "00:06.00 we were gold",
      "",
      "# The Turning Point",
      "00:07.00 I didn't wanna leave you",
      "00:08.00 I didn't wanna lie",
    ].join("\n"),
  );
});

Deno.test("addLessons stores an untimestamped outline from lyric lines", async () => {
  const model = queuedModel(["# Greetings\nBonjour le monde\nSalut encore"]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour le monde", "Salut encore"] },
    models: { addLessons: model.model },
  });

  await addLessons(ctx);

  assertEquals(
    store.data.lesson_outline,
    "# Greetings\nBonjour le monde\nSalut encore",
  );
  assertEquals(store.data.lessons, undefined);
  assertEquals(model.calls(), 1);
});

Deno.test("addLessons retries an empty response, then succeeds", async () => {
  const model = queuedModel(["", "# Greetings\nBonjour le monde\nSalut encore"]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { addLessons: model.model },
  });

  await addLessons(ctx);
  assertEquals(model.calls(), 2);
  assert(store.data.lesson_outline!.startsWith("# Greetings"));
});

Deno.test("materializeLessons attaches aligned timestamps to the outline", async () => {
  const { ctx, store } = makeCtx({
    data: {
      lesson_outline: "# Greetings\nBonjour le monde\nSalut encore",
      phrases: phrasesFixture(),
    },
  });

  await materializeLessons(ctx);

  assertEquals(
    store.data.lessons,
    "# Greetings\n00:05.00 Bonjour le monde\n00:10.00 Salut encore",
  );
});

Deno.test("addLessons records the failed LLM response after exhausting retries", async () => {
  // 6 attempts (1 + 5 retries), all empty.
  const model = queuedModel(["", "", "", "", "", ""]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { addLessons: model.model },
  });

  await assertRejects(() => addLessons(ctx), Error, "LLM returned nil");
  assertEquals(model.calls(), 6);

  const error = store.data.errors![0];
  assertEquals(error.step, "add_lessons");
  assertEquals(error.attempts, 6);
  assertEquals(error.agent_response, "");
});
