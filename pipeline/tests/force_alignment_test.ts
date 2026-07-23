import { assert, assertEquals, assertFalse, assertRejects } from "@std/assert";
import { forceAlignment } from "../src/steps/forceAlignment.ts";
import {
  alignedBatch,
  alignment,
  makeCtx,
  queuedModel,
  stubAlign,
  stubAudioWith,
} from "./helpers.ts";

Deno.test("ElevenLabs forced alignment creates timed phrases and words", async () => {
  const aligner = stubAlign([alignment(alignedBatch(1, 2))]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Line 1", "Line 2"], force_alignment_in_progress: true },
    prepareAudio: stubAudioWith(13),
    alignLyrics: aligner.align,
  });
  await forceAlignment(ctx);
  assertEquals(aligner.requests[0].text, "Line 1 Line 2");
  assertEquals(store.data.phrases?.map((phrase) => phrase.timestamp), ["00:00.00"]);
  assertEquals(store.data.phrases?.[0].words.map((word) => word.text), ["Line", "1", "Line", "2"]);
  assertEquals(store.data.lyric_lines, ["Line 1 Line 2"]);
  assertEquals(store.data.video_length_seconds, 13);
  assertFalse(store.data.force_alignment_in_progress);
});

Deno.test("an incomplete ElevenLabs alignment fails and remains resumable", async () => {
  const fallbackModel = queuedModel(["", ""]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Line 1", "Line 2"] },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: stubAudioWith(13),
    alignLyrics: stubAlign([alignment(alignedBatch(1, 1))]).align,
  });
  await assertRejects(() => forceAlignment(ctx));
  assert(store.data.force_alignment_in_progress);
  assertEquals(store.data.errors?.[0].step, "force_alignment");
});

Deno.test("yt-dlp failure falls back to Gemini structured line timestamps", async () => {
  const fallbackModel = queuedModel([{
    lines: [
      { line: "Bonjour monde", start_seconds: 2.5, end_seconds: 4.25 },
      { line: "Salut encore", start_seconds: 5, end_seconds: 7 },
    ],
  }]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour monde", "Salut encore"] },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: () => Promise.reject(new Error("yt-dlp failed")),
  });

  await forceAlignment(ctx);

  assertEquals(fallbackModel.calls(), 1);
  assertEquals(store.data.phrases?.map((phrase) => phrase.timestamp), ["00:02.50", "00:05.00"]);
  assertEquals(store.data.phrases?.map((phrase) => phrase.timestamp_end), [
    "00:04.25",
    "00:07.00",
  ]);
  assertEquals(store.data.phrases?.[0].words, [
    { text: "Bonjour", l1_start_index: 0, l1_end_index: 6 },
    { text: "monde", l1_start_index: 8, l1_end_index: 12 },
  ]);
  assertEquals(store.data.video_length_seconds, 7);
  assertFalse(store.data.force_alignment_in_progress);
});

Deno.test("invalid ElevenLabs output falls back to Gemini and keeps original lines", async () => {
  const fallbackModel = queuedModel([{
    lines: [{ line: "Gemini changed this", start_seconds: 1, end_seconds: 3 }],
  }]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["שלום עולם"] },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: stubAudioWith(13),
    alignLyrics: stubAlign([alignment([])]).align,
  });

  await forceAlignment(ctx);

  assertEquals(store.data.phrases?.[0].text_l1, "שלום עולם");
  assertEquals(store.data.phrases?.[0].words.map((word) => word.text), ["שלום", "עולם"]);
});
