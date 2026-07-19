import { assert, assertEquals, assertFalse, assertRejects } from "@std/assert";
import { extractLyrics, IncompleteTranscriptionError } from "../src/steps/extractLyrics.ts";
import { linesBatch, makeCtx, queuedModel, srt } from "./helpers.ts";

Deno.test("parses word-timed JSON into phrases with words", async () => {
  const model = queuedModel([
    {
      lines: [
        {
          line_start: "00:00:05,000",
          line_end: "00:00:08,000",
          line_text: "First line",
          words: [
            { word: "First", start: "00:00:05,000", end: "00:00:06,200" },
            { word: "line", start: "00:00:06,400", end: "00:00:08,000" },
          ],
        },
      ],
      has_more: false,
      video_length: "00:00:10,000",
    },
  ]);
  const { ctx, store } = makeCtx({ models: { extractLyrics: model.model } });

  await extractLyrics(ctx);

  const phrases = store.data.phrases!;
  assertEquals(phrases.length, 1);
  assertEquals(phrases[0].text_l1, "First line");
  assertEquals(phrases[0].timestamp, "00:05.00");
  assertEquals(phrases[0].timestamp_end, "00:08.00");
  assertEquals(phrases[0].words[0].text, "First");
  assertEquals(phrases[0].words[0].timestamp, "00:05.00");
  assertEquals(store.data.video_length_seconds, 10);
  assertFalse(store.data.extract_lyrics_in_progress);
  assertEquals(model.calls(), 1);
});

Deno.test("pages through the video until has_more is false", async () => {
  const model = queuedModel([
    { lines: linesBatch(1, 2), has_more: true, video_length: "00:00:40,000" },
    { lines: linesBatch(3, 4), has_more: false, video_length: "00:00:40,000" },
  ]);
  const { ctx, store, sink } = makeCtx({ models: { extractLyrics: model.model } });

  await extractLyrics(ctx);

  const phrases = store.data.phrases!;
  assertEquals(phrases.length, 4);
  assertEquals(phrases.map((p) => p.id), ["phrase_1", "phrase_2", "phrase_3", "phrase_4"]);
  assertEquals(phrases.map((p) => p.text_l1), ["Line 1", "Line 2", "Line 3", "Line 4"]);
  assertEquals(model.calls(), 2);

  // The second call continues the same conversation: system instructions, the
  // original video message, the first assistant answer, and the continuation
  // instruction.
  assertEquals(model.prompts[1].length, 4);

  // Phrases were persisted after every turn, not only at the end.
  const phraseSets = sink.ops.filter((op) => op.path === "phrases");
  assertEquals(phraseSets.length, 2);
  // deno-lint-ignore no-explicit-any
  assertEquals((phraseSets[0].value as any[]).length, 2);
});

Deno.test("dedupes repeated lines and drops backwards continuation lines", async () => {
  const repeated = linesBatch(2, 2)[0];
  const backwards = { ...linesBatch(1, 1)[0], line_text: "Hallucinated" };
  const model = queuedModel([
    { lines: linesBatch(1, 2), has_more: true, video_length: "00:00:40,000" },
    { lines: [repeated, backwards, ...linesBatch(3, 3)], has_more: false, video_length: "00:00:40,000" },
  ]);
  const { ctx, store } = makeCtx({ models: { extractLyrics: model.model } });

  await extractLyrics(ctx);

  assertEquals(store.data.phrases!.map((p) => p.text_l1), ["Line 1", "Line 2", "Line 3"]);
});

Deno.test("stops when a continuation makes no forward progress", async () => {
  const model = queuedModel([
    { lines: linesBatch(1, 2), has_more: true, video_length: "00:00:20,000" },
    // The model claims more content but only re-emits what we have.
    { lines: linesBatch(1, 2), has_more: true, video_length: "00:00:20,000" },
  ]);
  const { ctx, store } = makeCtx({ models: { extractLyrics: model.model } });

  await extractLyrics(ctx);

  assertEquals(store.data.phrases!.length, 2);
  assertEquals(model.calls(), 2);
});

Deno.test("retries a turn whose structured output is unparsable", async () => {
  const model = queuedModel([
    "not json {{{",
    { lines: linesBatch(1, 2), has_more: false, video_length: "00:00:20,000" },
  ]);
  const { ctx, store } = makeCtx({ models: { extractLyrics: model.model } });

  await extractLyrics(ctx);

  assertEquals(store.data.phrases!.length, 2);
  assertEquals(model.calls(), 2);
});

Deno.test("gives up after retries and records the raw response in data.errors", async () => {
  const model = queuedModel(["not json {{{", "still not json", "nope"]);
  const { ctx, store } = makeCtx({ models: { extractLyrics: model.model } });

  await assertRejects(() => extractLyrics(ctx));
  assertEquals(model.calls(), 3);

  const error = store.data.errors![0];
  assertEquals(error.step, "extract_lyrics");
  assert(error.agent_response?.includes("nope"));
  // The interrupted flag survives so the next run resumes the step.
  assert(store.data.extract_lyrics_in_progress);
});

Deno.test("fails on insufficient video coverage and keeps the resume flag", async () => {
  const model = queuedModel([
    // Lines end around 13s of a 100s video: 13% coverage.
    { lines: linesBatch(1, 2), has_more: false, video_length: srt(100) },
  ]);
  const { ctx, store } = makeCtx({ models: { extractLyrics: model.model } });

  await assertRejects(() => extractLyrics(ctx), IncompleteTranscriptionError, "only covered");

  // The partial transcription is preserved for the next attempt...
  assertEquals(store.data.phrases!.length, 2);
  // ...and the flag says the step is unfinished.
  assert(store.data.extract_lyrics_in_progress);
  assertEquals(store.data.errors![0].step, "extract_lyrics");
});

Deno.test("missing video length skips the coverage guard", async () => {
  const model = queuedModel([
    { lines: linesBatch(1, 1), has_more: false, video_length: "" },
  ]);
  const { ctx, store } = makeCtx({ models: { extractLyrics: model.model } });

  await extractLyrics(ctx);
  assertFalse(store.data.extract_lyrics_in_progress);
});
