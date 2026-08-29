import { assert, assertEquals, assertRejects, assertStringIncludes } from "@std/assert";
import { addLessonsPrompt } from "../src/prompts/addLessons.ts";
import {
  addLessons,
  matchLessonDataToPrompt,
  materializeLessons,
} from "../src/steps/addLessons.ts";
import { makeCtx, phrasesFixture, queuedModel } from "./helpers.ts";

Deno.test("addLessons prompt states the hard line-length limit", () => {
  assertStringIncludes(addLessonsPrompt("Arabic", "English"), "No line may exceed 20 words.");
});

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

Deno.test("addLessons capitalizes line starts without changing learner token boundaries", async () => {
  const model = queuedModel([{
    lessons: [{ title: "Peace", lines: ["the United States was at peace"] }],
  }]);
  const rawWords = ["the", "United", "States", "was", "at", "peace"];
  const { ctx, store } = makeCtx({
    clipLanguage: "English",
    data: {
      phrases: [{
        id: "phrase_1",
        text_l1: rawWords.join(" "),
        timestamp: "00:01.00",
        timestamp_end: "00:07.00",
        words: rawWords.map((text, index) => ({
          text,
          timestamp: `00:0${index + 1}.00`,
          timestamp_end: `00:0${index + 2}.00`,
        })),
      }],
    },
    models: { addLessons: model.model },
  });

  await addLessons(ctx);

  assertEquals(store.data.lyric_lines, ["The United States was at peace"]);
  assertEquals(store.data.phrases![0].words.map((word) => word.text), [
    "The",
    "United",
    "States",
    "was",
    "at",
    "peace",
  ]);
  assertEquals(store.data.phrases![0].words[0].timestamp, "00:01.00");
  assertEquals(store.data.phrases![0].words[0].timestamp_end, "00:02.00");
  assertEquals(store.data.phrases![0].words[0].l1_start_index, 0);
  assertEquals(store.data.phrases![0].words[0].l1_end_index, 2);
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

Deno.test("addLessons keeps aligned transcript text when the model rewrites a word", async () => {
  const model = queuedModel([
    { lessons: [{ title: "Greetings", lines: ["Bonjor monde Salut encore"] }] },
  ]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { addLessons: model.model },
  });

  await addLessons(ctx);
  assertEquals(model.calls(), 1);
  assertEquals(store.data.lyric_lines, ["Bonjour monde Salut encore"]);
});

Deno.test("addLessons splits long lines at periods, then commas, then the middle", async () => {
  const periodWords = Array.from({ length: 24 }, (_, index) => {
    if (index === 7) return `p${index + 1}.`;
    if (index === 11) return `p${index + 1},`;
    return `p${index + 1}`;
  });
  const commaWords = Array.from(
    { length: 22 },
    (_, index) => index === 9 ? `c${index + 1}،` : `c${index + 1}`,
  );
  const middleWords = Array.from({ length: 22 }, (_, index) => `m${index + 1}`);
  const allWords = [...periodWords, ...commaWords, ...middleWords];
  const model = queuedModel([{
    lessons: [
      { title: "Period", lines: [periodWords.join(" ")] },
      { title: "Comma", lines: [commaWords.join(" ")] },
      { title: "Middle", lines: [middleWords.join(" ")] },
    ],
  }]);
  const { ctx, store } = makeCtx({
    data: {
      phrases: [{
        id: "phrase_1",
        text_l1: allWords.join(" "),
        timestamp: "00:01.00",
        timestamp_end: "00:02.00",
        words: allWords.map((text) => ({
          text,
          timestamp: "00:01.00",
          timestamp_end: "00:02.00",
        })),
      }],
    },
    models: { addLessons: model.model },
  });

  await addLessons(ctx);

  assertEquals(model.calls(), 1);
  assertEquals(store.data.lyric_lines, [
    "P" + periodWords.slice(0, 8).join(" ").slice(1),
    "P" + periodWords.slice(8).join(" ").slice(1),
    "C" + commaWords.slice(0, 10).join(" ").slice(1),
    "C" + commaWords.slice(10).join(" ").slice(1),
    "M" + middleWords.slice(0, 11).join(" ").slice(1),
    "M" + middleWords.slice(11).join(" ").slice(1),
  ]);
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

Deno.test("addLessons preserves line timing while fallback words remain untimed", async () => {
  const model = queuedModel([{
    lessons: [{ title: "Greetings", lines: ["Bonjour monde", "Salut encore"] }],
  }]);
  const { ctx, store } = makeCtx({
    data: {
      phrases: [
        {
          id: "phrase_1",
          text_l1: "Bonjour, monde!",
          timestamp: "00:02.50",
          timestamp_end: "00:04.25",
          words: [
            { text: "Bonjour", l1_start_index: 0, l1_end_index: 6 },
            { text: "monde", l1_start_index: 9, l1_end_index: 13 },
          ],
        },
        {
          id: "phrase_2",
          text_l1: "Salut encore",
          timestamp: "00:05.00",
          timestamp_end: "00:07.00",
          words: [
            { text: "Salut", l1_start_index: 0, l1_end_index: 4 },
            { text: "encore", l1_start_index: 6, l1_end_index: 11 },
          ],
        },
      ],
    },
    models: { addLessons: model.model },
  });

  await addLessons(ctx);

  assertEquals(
    store.data.phrases?.map((phrase) => [
      phrase.timestamp,
      phrase.timestamp_end,
    ]),
    [
      ["00:02.50", "00:04.25"],
      ["00:05.00", "00:07.00"],
    ],
  );
  assertEquals(store.data.phrases?.[0].text_l1, "Bonjour, monde!");
  assertEquals(
    store.data.phrases?.flatMap((phrase) => phrase.words).some((word) =>
      word.timestamp || word.timestamp_end
    ),
    false,
  );
});

Deno.test("addLessons preserves only the word timings Gemini supplied", async () => {
  const model = queuedModel([{
    lessons: [{ title: "One", lines: ["First skipped last"] }],
  }]);
  const { ctx, store } = makeCtx({
    data: {
      phrases: [{
        id: "phrase_1",
        text_l1: "First skipped last",
        timestamp: "00:01.00",
        timestamp_end: "00:04.00",
        words: [
          { text: "First", timestamp: "00:01.00", timestamp_end: "00:01.50" },
          { text: "skipped" },
          { text: "last", timestamp: "00:03.00", timestamp_end: "00:04.00" },
        ],
      }],
    },
    models: { addLessons: model.model },
  });

  await addLessons(ctx);

  assertEquals(
    store.data.phrases?.[0].words.map((word) => [
      word.text,
      word.timestamp,
      word.timestamp_end,
    ]),
    [
      ["First", "00:01.00", "00:01.50"],
      ["skipped", undefined, undefined],
      ["last", "00:03.00", "00:04.00"],
    ],
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
  // Two attempts (one initial call plus one retry), both empty.
  const model = queuedModel(["", ""]);
  const { ctx, store } = makeCtx({
    data: { phrases: phrasesFixture() },
    models: { addLessons: model.model },
  });

  await assertRejects(() => addLessons(ctx));
  assertEquals(model.calls(), 2);

  const error = store.data.errors![0];
  assertEquals(error.step, "add_lessons");
  assertEquals(error.attempts, 2);
  assertEquals(error.agent_response, "");
});
