import { assert, assertEquals, assertFalse, assertRejects } from "@std/assert";
import { forceAlignment, IncompleteTranscriptionError } from "../src/steps/forceAlignment.ts";
import {
  alignedBatch,
  alignment,
  geminiAlignment,
  makeCtx,
  queuedModel,
  STUB_AUDIO_PATH,
  stubAlign,
  stubAudioWith,
  unusedModel,
} from "./helpers.ts";

// The step reads its input from data.lyric_lines, as extract_lyrics leaves it.
function lyricLines(from: number, to: number): string[] {
  const lines = [];
  for (let n = from; n <= to; n++) lines.push(`Line ${n}`);
  return lines;
}

Deno.test("aligns the saved lyric lines into phrases with words", async () => {
  const aligner = stubAlign([
    alignment([
      { text: "First", start: 5, end: 6.2 },
      { text: "line", start: 6.4, end: 8 },
    ]),
  ]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["First line"] },
    alignLyrics: aligner.align,
    prepareAudio: stubAudioWith(10),
  });

  await forceAlignment(ctx);

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
  assertFalse(store.data.force_alignment_in_progress);
  assertEquals(aligner.calls(), 1);
});

Deno.test("sends the lyrics text and downloaded audio to the aligner", async () => {
  const aligner = stubAlign([alignment(alignedBatch(1, 2))]);
  const { ctx } = makeCtx({
    data: { lyric_lines: lyricLines(1, 2) },
    alignLyrics: aligner.align,
  });

  await forceAlignment(ctx);

  assertEquals(aligner.requests[0].audioPath, STUB_AUDIO_PATH);
  assertEquals(aligner.requests[0].text, "Line 1\nLine 2");
});

Deno.test("groups the flat aligned word list back into lyric lines", async () => {
  const aligner = stubAlign([alignment(alignedBatch(1, 2))]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: lyricLines(1, 2) },
    alignLyrics: aligner.align,
    prepareAudio: stubAudioWith(20),
  });

  await forceAlignment(ctx);

  const phrases = store.data.phrases!;
  assertEquals(phrases.map((p) => p.id), ["phrase_1", "phrase_2"]);
  assertEquals(phrases.map((p) => p.text_l1), ["Line 1", "Line 2"]);
  assertEquals(phrases[1].timestamp, "00:10.00");
  assertEquals(phrases[1].timestamp_end, "00:13.00");
  assertEquals(phrases[1].words.map((w) => w.text), ["Line", "2"]);
});

Deno.test("retries a failed alignment call before falling back", async () => {
  const backup = unusedModel();
  const aligner = stubAlign([
    new Error("alignment down"),
    alignment(alignedBatch(1, 2)),
  ]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: lyricLines(1, 2) },
    models: { forceAlignment: backup.model },
    alignLyrics: aligner.align,
  });

  await forceAlignment(ctx);

  assertEquals(store.data.phrases!.length, 2);
  assertEquals(aligner.calls(), 2);
  assertEquals(backup.calls(), 0);
});

Deno.test("falls back to Gemini when the ElevenLabs alignment keeps failing", async () => {
  const backup = queuedModel([geminiAlignment(1, 2)]);
  const aligner = stubAlign([
    new Error("boom 1"),
    new Error("boom 2"),
    new Error("boom 3"),
  ]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: lyricLines(1, 2) },
    models: { forceAlignment: backup.model },
    alignLyrics: aligner.align,
    prepareAudio: stubAudioWith(20),
  });

  await forceAlignment(ctx);

  assertEquals(aligner.calls(), 3);
  assertEquals(backup.calls(), 1);
  const phrases = store.data.phrases!;
  assertEquals(phrases.map((p) => p.text_l1), ["Line 1", "Line 2"]);
  assertEquals(phrases[1].timestamp, "00:10.00");
  assertEquals(phrases[1].words.map((w) => w.text), ["Line", "2"]);
  // The download still succeeded, so the clip duration is recorded.
  assertEquals(store.data.video_length_seconds, 20);
  assertFalse(store.data.force_alignment_in_progress);
  assertEquals(store.data.errors ?? [], []);
});

Deno.test("falls back to Gemini when the audio download fails", async () => {
  const backup = queuedModel([geminiAlignment(1, 2)]);
  const aligner = stubAlign([]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: lyricLines(1, 2) },
    models: { forceAlignment: backup.model },
    alignLyrics: aligner.align,
    prepareAudio: () => Promise.reject(new Error("yt-dlp exited with code 1")),
  });

  await forceAlignment(ctx);

  // ElevenLabs was never reached: there were no bytes to send it.
  assertEquals(aligner.calls(), 0);
  assertEquals(backup.calls(), 1);
  assertEquals(store.data.phrases!.length, 2);
  // No download means no duration, so the coverage guard has nothing to judge.
  assertEquals(store.data.video_length_seconds, undefined);
});

Deno.test("sends the lyrics and the video URL to the backup aligner", async () => {
  const backup = queuedModel([geminiAlignment(1, 2)]);
  const { ctx } = makeCtx({
    data: { lyric_lines: lyricLines(1, 2) },
    models: { forceAlignment: backup.model },
    alignLyrics: () => Promise.reject(new Error("down")),
  });

  await forceAlignment(ctx);

  const content = JSON.stringify(backup.prompts[0]);
  assert(content.includes("Line 1\\nLine 2"), content);
  assert(content.includes("test123"), content);
});

Deno.test("retries an unusable backup response", async () => {
  const backup = queuedModel(["not json at all", geminiAlignment(1, 2)]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: lyricLines(1, 2) },
    models: { forceAlignment: backup.model },
    alignLyrics: () => Promise.reject(new Error("down")),
  });

  await forceAlignment(ctx);

  assertEquals(backup.calls(), 2);
  assertEquals(store.data.phrases!.length, 2);
});

Deno.test("records both failures when the backup fails too", async () => {
  const backup = queuedModel(["nonsense", "still nonsense"]);
  const aligner = stubAlign([
    new Error("boom 1"),
    new Error("boom 2"),
    new Error("boom 3"),
  ]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: lyricLines(1, 2) },
    models: { forceAlignment: backup.model },
    alignLyrics: aligner.align,
  });

  await assertRejects(() => forceAlignment(ctx));
  assertEquals(aligner.calls(), 3);
  assertEquals(backup.calls(), 2);

  const error = store.data.errors![0];
  assertEquals(error.step, "force_alignment");
  // Both causes are named, so the log says which half of the step broke.
  assert(error.error_message?.includes("boom 3"), error.error_message);
  assert(error.error_message?.includes("backup"), error.error_message);
  // The lines that failed to align and the last backup response are inspectable.
  assertEquals(error.input_lines, ["Line 1", "Line 2"]);
  assertEquals(error.agent_response, "still nonsense");
  // The interrupted flag survives so the next run resumes the step.
  assert(store.data.force_alignment_in_progress);
});

Deno.test("fails on insufficient video coverage and keeps the resume flag", async () => {
  // Lyrics end around 13s of a 100s clip: 13% coverage.
  const aligner = stubAlign([alignment(alignedBatch(1, 2))]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: lyricLines(1, 2) },
    alignLyrics: aligner.align,
    prepareAudio: stubAudioWith(100),
  });

  await assertRejects(() => forceAlignment(ctx), IncompleteTranscriptionError, "only covered");

  // The partial alignment is preserved for inspection...
  assertEquals(store.data.phrases!.length, 2);
  // ...and the flag says the step is unfinished.
  assert(store.data.force_alignment_in_progress);
  assertEquals(store.data.errors![0].step, "force_alignment");
});

Deno.test("missing clip duration skips the coverage guard", async () => {
  const aligner = stubAlign([alignment(alignedBatch(1, 1))]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: lyricLines(1, 1) },
    alignLyrics: aligner.align,
    prepareAudio: stubAudioWith(null),
  });

  await forceAlignment(ctx);

  assertFalse(store.data.force_alignment_in_progress);
  assertEquals(store.data.video_length_seconds, undefined);
});

Deno.test("lines the alignment ran out of words for are dropped", async () => {
  // Three lyric lines but aligned words only for the first two.
  const aligner = stubAlign([alignment(alignedBatch(1, 2))]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: lyricLines(1, 3) },
    alignLyrics: aligner.align,
    prepareAudio: stubAudioWith(20),
  });

  await forceAlignment(ctx);

  assertEquals(store.data.phrases!.map((p) => p.text_l1), ["Line 1", "Line 2"]);
});
