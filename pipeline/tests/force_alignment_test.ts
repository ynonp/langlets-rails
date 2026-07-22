import { assert, assertEquals, assertFalse, assertRejects } from "@std/assert";
import { forceAlignment } from "../src/steps/forceAlignment.ts";
import { alignedBatch, alignment, makeCtx, stubAlign, stubAudioWith } from "./helpers.ts";

Deno.test("ElevenLabs forced alignment creates timed phrases and words", async () => {
  const aligner = stubAlign([alignment(alignedBatch(1, 2))]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Line 1", "Line 2"], force_alignment_in_progress: true },
    prepareAudio: stubAudioWith(13),
    alignLyrics: aligner.align,
  });
  await forceAlignment(ctx);
  assertEquals(aligner.requests[0].text, "Line 1\nLine 2");
  assertEquals(store.data.phrases?.map((phrase) => phrase.timestamp), ["00:00.00", "00:10.00"]);
  assertEquals(store.data.phrases?.[0].words.map((word) => word.text), ["Line", "1"]);
  assertEquals(store.data.video_length_seconds, 13);
  assertFalse(store.data.force_alignment_in_progress);
});

Deno.test("an incomplete ElevenLabs alignment fails and remains resumable", async () => {
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Line 1", "Line 2"] },
    prepareAudio: stubAudioWith(13),
    alignLyrics: stubAlign([alignment(alignedBatch(1, 1))]).align,
  });
  await assertRejects(() => forceAlignment(ctx), Error, "aligned 1 of 2");
  assert(store.data.force_alignment_in_progress);
  assertEquals(store.data.errors?.[0].step, "force_alignment");
});
