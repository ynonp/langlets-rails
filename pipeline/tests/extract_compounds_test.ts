import { assert, assertEquals, assertThrows } from "@std/assert";
import {
  extractCompounds,
  materializeLearnerTokens,
  parseTokenArray,
} from "../src/steps/extractCompounds.ts";
import { makeCtx, queuedModel } from "./helpers.ts";

Deno.test("extractCompounds distinguishes repeated text by its contextual occurrence", async () => {
  const text = "The hot dog barked. I ate a hot dog.";
  const rawWords = ["The", "hot", "dog", "barked.", "I", "ate", "a", "hot", "dog."];
  const starts = [0, 4, 8, 12, 20, 22, 26, 28, 32];
  const model = queuedModel([[
    "The",
    "hot",
    "dog",
    "barked.",
    "I",
    "ate",
    "a",
    "hot dog.",
  ]]);
  const { ctx, store } = makeCtx({
    clipLanguage: "English",
    data: {
      phrases: [{
        id: "phrase_1",
        text_l1: text,
        timestamp: "00:01.00",
        timestamp_end: "00:10.00",
        words: rawWords.map((word, index) => ({
          text: word,
          timestamp: `00:0${index + 1}.00`,
          timestamp_end: `00:${String(index + 2).padStart(2, "0")}.00`,
          l1_start_index: starts[index],
          l1_end_index: starts[index] + word.replace(/\p{P}+$/u, "").length - 1,
        })),
      }],
    },
    models: { extractCompounds: model.model },
  });

  await extractCompounds(ctx);

  assertEquals(store.data.phrases![0].words.map((word) => word.text), [
    "The",
    "hot",
    "dog",
    "barked.",
    "I",
    "ate",
    "a",
    "hot dog.",
  ]);
  const compound = store.data.phrases![0].words.at(-1)!;
  assertEquals(compound.timestamp, "00:08.00");
  assertEquals(compound.timestamp_end, "00:10.00");
  assertEquals(compound.l1_start_index, 28);
  assertEquals(compound.l1_end_index, 34);
  assertEquals(store.data.learner_tokenization_version, 1);
  assertEquals(model.calls(), 1);
});

Deno.test("materializeLearnerTokens makes an Arabic title one timed learner token", () => {
  const phrases = [{
    id: "phrase_1",
    text_l1: "كان قائد الأركان",
    timestamp: "00:01.00",
    timestamp_end: "00:03.00",
    words: [
      {
        text: "كان",
        timestamp: "00:01.00",
        timestamp_end: "00:01.50",
        l1_start_index: 0,
        l1_end_index: 2,
      },
      {
        text: "قائد",
        timestamp: "00:01.50",
        timestamp_end: "00:02.00",
        l1_start_index: 4,
        l1_end_index: 7,
      },
      {
        text: "الأركان",
        timestamp: "00:02.00",
        timestamp_end: "00:03.00",
        l1_start_index: 9,
        l1_end_index: 15,
      },
    ],
  }];

  const result = materializeLearnerTokens(phrases, ["كان", "قائد الأركان"]);

  assertEquals(result[0].words[1], {
    text: "قائد الأركان",
    timestamp: "00:01.50",
    timestamp_end: "00:03.00",
    l1_start_index: 4,
    l1_end_index: 15,
  });
});

Deno.test("extractCompounds retries invalid coverage then preserves original words without a terminal error", async () => {
  const model = queuedModel([
    ["Bonjour"],
    ["Bonjour", "wrong"],
  ]);
  const original = [{
    id: "phrase_1",
    text_l1: "Bonjour monde",
    timestamp: "00:01.00",
    timestamp_end: "00:02.00",
    words: [
      { text: "Bonjour", timestamp: "00:01.00", timestamp_end: "00:01.50" },
      { text: "monde", timestamp: "00:01.50", timestamp_end: "00:02.00" },
    ],
  }];
  const { ctx, store } = makeCtx({
    data: { phrases: original },
    models: { extractCompounds: model.model },
  });

  await extractCompounds(ctx);

  assertEquals(store.data.phrases, original);
  assertEquals(store.data.learner_tokenization_version, 1);
  assertEquals(model.calls(), 2);
  assertEquals(store.data.errors, undefined);
});

Deno.test("materializeLearnerTokens rejects a compound crossing lesson lines", () => {
  const phrases = [
    {
      id: "phrase_1",
      text_l1: "New",
      timestamp: "00:01.00",
      timestamp_end: "00:02.00",
      words: [{ text: "New" }],
    },
    {
      id: "phrase_2",
      text_l1: "York",
      timestamp: "00:02.00",
      timestamp_end: "00:03.00",
      words: [{ text: "York" }],
    },
  ];

  assertThrows(
    () => materializeLearnerTokens(phrases, ["New York"]),
    Error,
    "crosses a lesson line",
  );
});

Deno.test("parseTokenArray accepts a fenced array and rejects non-string entries", () => {
  assertEquals(parseTokenArray('```json\n["قائد الأركان"]\n```'), ["قائد الأركان"]);
  assertThrows(
    () => parseTokenArray('["word", 2]'),
    Error,
    "array of non-empty strings",
  );
});
