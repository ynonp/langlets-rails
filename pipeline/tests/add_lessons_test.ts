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

Deno.test("addLessons creates semantic phrases and both lesson representations", async () => {
  const model = queuedModel([{
    lessons: [{ title: "Greetings", lines: ["Bonjour monde", "Salut encore"] }],
  }]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { addLessons: model.model },
  });

  await addLessons(ctx);

  assertEquals(
    store.data.lesson_outline,
    "# Greetings\nBonjour monde\nSalut encore",
  );
  assertEquals(store.data.lessons, "# Greetings\n00:05.00 Bonjour monde\n00:10.00 Salut encore");
  assertEquals(store.data.lyric_lines, ["Bonjour monde", "Salut encore"]);
  assertEquals(store.data.phrases?.[0].words[0].l1_start_index, 0);
  assertEquals(store.data.phrases?.[0].words[0].l1_end_index, 6);
  assertEquals(store.data.phrases?.[0].words[1].l1_start_index, 8);
  assertEquals(store.data.phrases?.[0].words[1].l1_end_index, 12);
  assertEquals(model.calls(), 1);
});

Deno.test("addLessons retries invalid structured output, then succeeds", async () => {
  const model = queuedModel([
    "",
    { lessons: [{ title: "Greetings", lines: ["Bonjour monde Salut encore"] }] },
  ]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { addLessons: model.model },
  });

  await addLessons(ctx);
  assertEquals(model.calls(), 2);
  assert(store.data.lesson_outline!.startsWith("# Greetings"));
});

Deno.test("addLessons rejects rewritten transcript text before retrying", async () => {
  const model = queuedModel([
    { lessons: [{ title: "Broken", lines: ["Bonjour le monde Salut encore"] }] },
    { lessons: [{ title: "Fixed", lines: ["Bonjour monde Salut encore"] }] },
  ]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { addLessons: model.model },
  });

  await addLessons(ctx);
  assertEquals(model.calls(), 2);
  assertEquals(store.data.lyric_lines, ["Bonjour monde Salut encore"]);
});

Deno.test("semantic materialization writes inclusive spans and excludes punctuation", async () => {
  const model = queuedModel([{
    lessons: [{ title: "Lados", lines: ["Soy amable."] }],
  }]);
  const { ctx, store } = makeCtx({
    data: {
      phrases: [{
        id: "phrase_1",
        text_l1: "Soy amable.",
        timestamp: "00:01.00",
        timestamp_end: "00:02.00",
        words: [
          { text: "Soy", timestamp: "00:01.00", timestamp_end: "00:01.30" },
          { text: "amable.", timestamp: "00:01.40", timestamp_end: "00:02.00" },
        ],
      }],
    },
    models: { addLessons: model.model },
  });

  await addLessons(ctx);

  assertEquals(
    store.data.phrases?.[0].words.map((word) => [word.l1_start_index, word.l1_end_index]),
    [[0, 2], [4, 9]],
  );
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

  await assertRejects(() => addLessons(ctx));
  assertEquals(model.calls(), 6);

  const error = store.data.errors![0];
  assertEquals(error.step, "add_lessons");
  assertEquals(error.attempts, 6);
  assertEquals(error.agent_response, "");
});
