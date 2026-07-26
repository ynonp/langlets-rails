import { assert, assertEquals, assertFalse, assertRejects } from "@std/assert";
import { AudioVerificationUnavailableError } from "../src/audio.ts";
import { forceAlignment } from "../src/steps/forceAlignment.ts";
import {
  alignedBatch,
  alignment,
  makeCtx,
  queuedModel,
  speechFixture,
  stubAlign,
  stubAudioWith,
  TIKTOK_URL,
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

Deno.test("yt-dlp failure falls back to Gemini structured word timestamps", async () => {
  const fallbackModel = queuedModel([{
    words: [
      { word: "Bonjour", start_seconds: 2.5, end_seconds: 3.25 },
      { word: "monde", start_seconds: 3.4, end_seconds: 4.25 },
      { word: "salut", start_seconds: 5, end_seconds: 6 },
      { word: "encore", start_seconds: 6.2, end_seconds: 7 },
    ],
  }]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour monde, Salut encore"] },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: () => Promise.reject(new Error("yt-dlp failed")),
  });

  await forceAlignment(ctx);

  assertEquals(fallbackModel.calls(), 1);
  // One provisional phrase, exactly like the ElevenLabs path: add_lessons owns
  // the partition into semantic lines.
  assertEquals(store.data.phrases?.length, 1);
  const phrase = store.data.phrases![0];
  assertEquals(phrase.text_l1, "Bonjour monde, Salut encore");
  assertEquals(phrase.timestamp, "00:02.50");
  assertEquals(phrase.timestamp_end, "00:07.00");
  // Word-level timings are the whole point of the fallback — karaoke
  // highlighting and the word-order activities are built on them.
  assertEquals(phrase.words.map((word) => word.text), ["Bonjour", "monde,", "Salut", "encore"]);
  assertEquals(phrase.words[1].timestamp, "00:03.40");
  assertEquals(phrase.words[1].timestamp_end, "00:04.25");
  assertEquals(phrase.words[3].timestamp_end, "00:07.00");
  // Character spans, which token translation indexes against.
  assertEquals(phrase.words[0].l1_start_index, 0);
  assertEquals(phrase.words[3].l1_end_index, 26);
  assertEquals(store.data.lyric_lines, ["Bonjour monde, Salut encore"]);
  assertEquals(store.data.video_length_seconds, 7);
  assertFalse(store.data.force_alignment_in_progress);
});

Deno.test("a Gemini fallback that resplits the transcript fails instead of silently reshaping it", async () => {
  // The failure this replaces: Gemini answered a one-line transcript with 33
  // lines of its own choosing.
  const fallbackModel = queuedModel([
    { words: [{ word: "Bonjour monde", start_seconds: 1, end_seconds: 3 }] },
    { words: [{ word: "Bonjour monde", start_seconds: 1, end_seconds: 3 }] },
  ]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour monde"] },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: () => Promise.reject(new Error("yt-dlp failed")),
  });

  await assertRejects(
    () => forceAlignment(ctx),
    Error,
    "Gemini timestamped 1 of 2 transcript words",
  );
  assertEquals(store.data.phrases, undefined);
});

Deno.test("a Gemini fallback that rewrites a word fails rather than corrupting the transcript", async () => {
  const returned = {
    words: [
      { word: "Bonjour", start_seconds: 1, end_seconds: 2 },
      { word: "tout", start_seconds: 2, end_seconds: 3 },
    ],
  };
  const fallbackModel = queuedModel([returned, returned]);
  const { ctx } = makeCtx({
    data: { lyric_lines: ["Bonjour monde"] },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: () => Promise.reject(new Error("yt-dlp failed")),
  });

  await assertRejects(() => forceAlignment(ctx), Error, `Gemini returned "tout"`);
});

Deno.test("Gemini punctuation and case differences do not fail the run", async () => {
  const fallbackModel = queuedModel([{
    words: [
      { word: "bonjour,", start_seconds: 1, end_seconds: 2 },
      { word: "l'monde", start_seconds: 2, end_seconds: 3 },
    ],
  }]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour l’monde!"] },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: () => Promise.reject(new Error("yt-dlp failed")),
  });

  await forceAlignment(ctx);

  // The transcript's own text survives; only the timings come from Gemini.
  assertEquals(store.data.phrases?.[0].text_l1, "Bonjour l’monde!");
  assertEquals(store.data.phrases?.[0].words.map((word) => word.text), ["Bonjour", "l’monde!"]);
});

Deno.test("an unverifiable host fails the step instead of falling back to Gemini", async () => {
  // Gemini can timestamp lines without touching audio, so this failure would
  // otherwise vanish into a degraded-but-green import — every course silently
  // losing word-level timings until someone noticed.
  const fallbackModel = queuedModel([{
    words: [
      { word: "Bonjour", start_seconds: 1, end_seconds: 2 },
      { word: "monde", start_seconds: 2, end_seconds: 3 },
    ],
  }]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour monde"] },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: () =>
      Promise.reject(new AudioVerificationUnavailableError("ffprobe", new Error("no run access"))),
  });

  await assertRejects(() => forceAlignment(ctx), Error, "Audio verification is required");

  // Not retried either: the host will not fix itself between attempts.
  assertEquals(fallbackModel.calls(), 0);
  assertEquals(store.data.errors![0].step, "force_alignment");
  assertEquals(store.data.phrases, undefined);
});

Deno.test("invalid ElevenLabs output falls back to Gemini and keeps original words", async () => {
  const fallbackModel = queuedModel([{
    words: [
      { word: "שלום", start_seconds: 1, end_seconds: 2 },
      { word: "עולם", start_seconds: 2, end_seconds: 3 },
    ],
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
  assertEquals(store.data.phrases?.[0].words[1].timestamp, "00:02.00");
});

Deno.test("stashed speech-to-text words are used instead of downloading audio", async () => {
  const align = stubAlign([alignment(alignedBatch(1, 2))]);
  const { ctx, store } = makeCtx({
    youtubeurl: TIKTOK_URL,
    data: { lyric_lines: ["Line 1 Line 2"], stt_words: speechFixture(1, 2).words },
    // Both would throw if reached: TikTok must not touch yt-dlp or forced
    // alignment, because Scribe already returned per-word timings.
    prepareAudio: () => {
      throw new Error("audio download must not run for TikTok");
    },
    alignLyrics: align.align,
  });

  await forceAlignment(ctx);

  assertEquals(align.calls(), 0);
  assertEquals(store.data.phrases?.length, 1);
  assertEquals(store.data.phrases?.[0].text_l1, "Line 1 Line 2");
  assertFalse(store.data.force_alignment_in_progress);
});

Deno.test("speech-to-text phrases carry per-word timestamps and a video length", async () => {
  const { ctx, store } = makeCtx({
    youtubeurl: TIKTOK_URL,
    data: { lyric_lines: ["Line 1 Line 2"], stt_words: speechFixture(1, 2).words },
  });

  await forceAlignment(ctx);

  const phrase = store.data.phrases![0];
  assertEquals(phrase.timestamp, "00:00.00");
  assertEquals(phrase.words.map((word) => word.text), ["Line", "1", "Line", "2"]);
  // Word timing is what karaoke highlighting and the word-order activities need;
  // without it the course silently degrades to line-only highlighting.
  assertEquals(phrase.words[0].timestamp, "00:00.00");
  assertEquals(phrase.words[0].timestamp_end, "00:01.00");
  assertEquals(phrase.words[3].timestamp_end, "00:13.00");
  // Character spans, which token translation indexes against.
  assertEquals(phrase.words[0].l1_start_index, 0);
  assertEquals(phrase.words[3].l1_end_index, 12);
  assertEquals(store.data.video_length_seconds, 13);
});
