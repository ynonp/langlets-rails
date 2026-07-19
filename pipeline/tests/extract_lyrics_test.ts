import { assert, assertEquals, assertFalse, assertRejects } from "@std/assert";
import { extractLyrics, IncompleteTranscriptionError } from "../src/steps/extractLyrics.ts";
import {
  alignedBatch,
  alignment,
  lyricsText,
  makeCtx,
  queuedModel,
  STUB_AUDIO_PATH,
  stubAlign,
  stubAudioWith,
} from "./helpers.ts";

Deno.test("aligns the Gemini lyrics into phrases with words", async () => {
  const model = queuedModel(["First line"]);
  const aligner = stubAlign([
    alignment([
      { text: "First", start: 5, end: 6.2 },
      { text: "line", start: 6.4, end: 8 },
    ]),
  ]);
  const { ctx, store } = makeCtx({
    models: { extractLyrics: model.model },
    alignLyrics: aligner.align,
    prepareAudio: stubAudioWith(10),
  });

  await extractLyrics(ctx);

  const phrases = store.data.phrases!;
  assertEquals(phrases.length, 1);
  assertEquals(phrases[0].id, "phrase_1");
  assertEquals(phrases[0].text_l1, "First line");
  assertEquals(phrases[0].timestamp, "00:05.00");
  assertEquals(phrases[0].timestamp_end, "00:08.00");
  assertEquals(phrases[0].words[0].text, "First");
  assertEquals(phrases[0].words[0].timestamp, "00:05.00");
  assertEquals(phrases[0].words[0].timestamp_end, "00:06.20");
  assertEquals(phrases[0].words[0].l1_start_index, 0);
  assertEquals(store.data.video_length_seconds, 10);
  assertFalse(store.data.extract_lyrics_in_progress);
  assertEquals(model.calls(), 1);
  assertEquals(aligner.calls(), 1);
});

Deno.test("sends the lyrics text and downloaded audio to the aligner", async () => {
  const model = queuedModel([lyricsText(1, 2)]);
  const aligner = stubAlign([alignment(alignedBatch(1, 2))]);
  const { ctx } = makeCtx({
    models: { extractLyrics: model.model },
    alignLyrics: aligner.align,
  });

  await extractLyrics(ctx);

  assertEquals(aligner.requests[0].audioPath, STUB_AUDIO_PATH);
  assertEquals(aligner.requests[0].text, "Line 1\nLine 2");
});

Deno.test("groups the flat aligned word list back into lyric lines", async () => {
  const model = queuedModel([lyricsText(1, 2)]);
  const aligner = stubAlign([alignment(alignedBatch(1, 2))]);
  const { ctx, store } = makeCtx({
    models: { extractLyrics: model.model },
    alignLyrics: aligner.align,
    prepareAudio: stubAudioWith(20),
  });

  await extractLyrics(ctx);

  const phrases = store.data.phrases!;
  assertEquals(phrases.map((p) => p.id), ["phrase_1", "phrase_2"]);
  assertEquals(phrases.map((p) => p.text_l1), ["Line 1", "Line 2"]);
  assertEquals(phrases[1].timestamp, "00:10.00");
  assertEquals(phrases[1].timestamp_end, "00:13.00");
  assertEquals(phrases[1].words.map((w) => w.text), ["Line", "2"]);
});

Deno.test("retries a lyrics response with no usable lines", async () => {
  const model = queuedModel(["```\n```", lyricsText(1, 2)]);
  const aligner = stubAlign([alignment(alignedBatch(1, 2))]);
  const { ctx, store } = makeCtx({
    models: { extractLyrics: model.model },
    alignLyrics: aligner.align,
  });

  await extractLyrics(ctx);

  assertEquals(store.data.phrases!.length, 2);
  assertEquals(model.calls(), 2);
});

Deno.test("retries a failed alignment call", async () => {
  const model = queuedModel([lyricsText(1, 2)]);
  const aligner = stubAlign([
    new Error("alignment down"),
    alignment(alignedBatch(1, 2)),
  ]);
  const { ctx, store } = makeCtx({
    models: { extractLyrics: model.model },
    alignLyrics: aligner.align,
  });

  await extractLyrics(ctx);

  assertEquals(store.data.phrases!.length, 2);
  assertEquals(aligner.calls(), 2);
});

Deno.test("gives up after alignment retries and records the lyrics in data.errors", async () => {
  const model = queuedModel([lyricsText(1, 2)]);
  const aligner = stubAlign([
    new Error("boom 1"),
    new Error("boom 2"),
    new Error("boom 3"),
  ]);
  const { ctx, store } = makeCtx({
    models: { extractLyrics: model.model },
    alignLyrics: aligner.align,
  });

  await assertRejects(() => extractLyrics(ctx));
  assertEquals(aligner.calls(), 3);

  const error = store.data.errors![0];
  assertEquals(error.step, "extract_lyrics");
  assert(error.error_message?.includes("boom 3"));
  // The lyrics text that failed to align is inspectable.
  assert(error.agent_response?.includes("Line 1"));
  // The interrupted flag survives so the next run resumes the step.
  assert(store.data.extract_lyrics_in_progress);
});

Deno.test("fails on insufficient video coverage and keeps the resume flag", async () => {
  // Lyrics end around 13s of a 100s clip: 13% coverage.
  const model = queuedModel([lyricsText(1, 2)]);
  const aligner = stubAlign([alignment(alignedBatch(1, 2))]);
  const { ctx, store } = makeCtx({
    models: { extractLyrics: model.model },
    alignLyrics: aligner.align,
    prepareAudio: stubAudioWith(100),
  });

  await assertRejects(() => extractLyrics(ctx), IncompleteTranscriptionError, "only covered");

  // The partial transcription is preserved for inspection...
  assertEquals(store.data.phrases!.length, 2);
  // ...and the flag says the step is unfinished.
  assert(store.data.extract_lyrics_in_progress);
  assertEquals(store.data.errors![0].step, "extract_lyrics");
});

Deno.test("missing clip duration skips the coverage guard", async () => {
  const model = queuedModel([lyricsText(1, 1)]);
  const aligner = stubAlign([alignment(alignedBatch(1, 1))]);
  const { ctx, store } = makeCtx({
    models: { extractLyrics: model.model },
    alignLyrics: aligner.align,
    prepareAudio: stubAudioWith(null),
  });

  await extractLyrics(ctx);

  assertFalse(store.data.extract_lyrics_in_progress);
  assertEquals(store.data.video_length_seconds, undefined);
});

Deno.test("lines the alignment ran out of words for are dropped", async () => {
  // Three lyric lines but aligned words only for the first two.
  const model = queuedModel([lyricsText(1, 3)]);
  const aligner = stubAlign([alignment(alignedBatch(1, 2))]);
  const { ctx, store } = makeCtx({
    models: { extractLyrics: model.model },
    alignLyrics: aligner.align,
    prepareAudio: stubAudioWith(20),
  });

  await extractLyrics(ctx);

  assertEquals(store.data.phrases!.map((p) => p.text_l1), ["Line 1", "Line 2"]);
});
