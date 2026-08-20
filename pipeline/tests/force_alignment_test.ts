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

Deno.test("ElevenLabs splitting a word does not cost the alignment", async () => {
  // "don" + "'t" is one transcript word. Kept apart it would become two
  // clickable vocabulary items, one of them "'t".
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Don't speak"] },
    prepareAudio: stubAudioWith(13),
    alignLyrics: stubAlign([alignment([
      { text: "don", start: 0, end: 1 },
      { text: "'t", start: 1, end: 1.5 },
      { text: "speak", start: 2, end: 3 },
    ])]).align,
  });

  await forceAlignment(ctx);

  const phrase = store.data.phrases![0];
  assertEquals(phrase.text_l1, "Don't speak");
  assertEquals(phrase.words.map((word) => word.text), ["Don't", "speak"]);
  // The rejoined word spans both pieces ElevenLabs returned.
  assertEquals(phrase.words[0].timestamp, "00:00.00");
  assertEquals(phrase.words[0].timestamp_end, "00:01.50");
  assertEquals(phrase.words[1].timestamp, "00:02.00");
});

Deno.test("ElevenLabs merging two words splits their span back apart", async () => {
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["New York"] },
    prepareAudio: stubAudioWith(13),
    alignLyrics: stubAlign([alignment([{ text: "New York", start: 0, end: 7 }])]).align,
  });

  await forceAlignment(ctx);

  const phrase = store.data.phrases![0];
  assertEquals(phrase.words.map((word) => word.text), ["New", "York"]);
  // Seven letters over seven seconds, so the boundary falls after "New".
  assertEquals(phrase.words[0].timestamp_end, "00:03.00");
  assertEquals(phrase.words[1].timestamp, "00:03.00");
});

Deno.test("caption note symbols never reach the word stream", async () => {
  // YouTube wraps music-video caption lines in ♪ … ♪. Nothing in the audio
  // corresponds to them, and add_token_translations would make each one a
  // clickable word.
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["♪ Don't speak ♪"] },
    prepareAudio: stubAudioWith(13),
    alignLyrics: stubAlign([alignment([
      { text: "Don't", start: 0, end: 1 },
      { text: "speak", start: 1, end: 2 },
    ])]).align,
  });

  await forceAlignment(ctx);

  assertEquals(store.data.phrases![0].words.map((word) => word.text), ["Don't", "speak"]);
  assertEquals(store.data.phrases![0].text_l1, "Don't speak");
  assertEquals(store.data.lyric_lines, ["Don't speak"]);
});

Deno.test("an ElevenLabs alignment of different text falls back to Gemini", async () => {
  // Tokenization is the provider's business; the words themselves are not.
  const fallbackModel = queuedModel([{
    words: [
      { word: "Bonjour", start_seconds: 1, end_seconds: 2 },
      { word: "monde", start_seconds: 2, end_seconds: 3 },
    ],
  }]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour monde"] },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: stubAudioWith(13),
    alignLyrics: stubAlign([alignment([
      { text: "Bonjour", start: 0, end: 1 },
      { text: "tout", start: 1, end: 2 },
    ])]).align,
  });

  await forceAlignment(ctx);

  assertEquals(fallbackModel.calls(), 1);
  assertEquals(store.data.phrases?.[0].words.map((word) => word.text), ["Bonjour", "monde"]);
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

Deno.test("Gemini fallback infers missing word ends from the next start", async () => {
  const fallbackModel = queuedModel([{
    words: [
      { word: "Bonjour", start_seconds: 2.5 },
      { word: "monde", start_seconds: 3.4, end_seconds: 4.25 },
      { word: "salut", start_seconds: 5 },
      { word: "encore", start_seconds: 6.2 },
    ],
  }]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["Bonjour monde, Salut encore"] },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: () => Promise.reject(new Error("yt-dlp failed")),
  });

  await forceAlignment(ctx);

  const words = store.data.phrases![0].words;
  assertEquals(words[0].timestamp_end, "00:03.40");
  assertEquals(words[1].timestamp_end, "00:04.25");
  assertEquals(words[2].timestamp_end, "00:06.20");
  assertEquals(words[3].timestamp_end, "00:08.20");
  assertEquals(store.data.phrases![0].timestamp_end, "00:08.20");
  assertEquals(store.data.video_length_seconds, 8.2);
  assertFalse(store.data.force_alignment_in_progress);
});

Deno.test("a Gemini fallback that merges transcript words fails instead of silently reshaping it", async () => {
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
    `Gemini returned "Bonjour monde" outside the transcript word order`,
  );
  assertEquals(store.data.phrases, undefined);
});

Deno.test("Gemini may omit middle word timestamps when every line has timed bounds", async () => {
  const fallbackModel = queuedModel([{
    words: [
      { word: "First", start_seconds: 1, end_seconds: 1.5 },
      { word: "skipped" },
      { word: "sentence", start_seconds: 3, end_seconds: 4 },
      { word: "Second", start_seconds: 5, end_seconds: 5.5 },
      { word: "missing" },
      { word: "middle" },
      { word: "too", start_seconds: 8, end_seconds: 9 },
    ],
  }]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["First skipped sentence", "Second missing middle too"] },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: () => Promise.reject(new Error("yt-dlp failed")),
  });

  await forceAlignment(ctx);

  assertEquals(store.data.phrases?.map((phrase) => phrase.text_l1), [
    "First skipped sentence",
    "Second missing middle too",
  ]);
  assertEquals(store.data.phrases?.map((phrase) => [phrase.timestamp, phrase.timestamp_end]), [
    ["00:01.00", "00:04.00"],
    ["00:05.00", "00:09.00"],
  ]);
  assertEquals(
    store.data.phrases?.flatMap((phrase) =>
      phrase.words.map((word) => [word.text, word.timestamp, word.timestamp_end])
    ),
    [
      ["First", "00:01.00", "00:01.50"],
      ["skipped", undefined, undefined],
      ["sentence", "00:03.00", "00:04.00"],
      ["Second", "00:05.00", "00:05.50"],
      ["missing", undefined, undefined],
      ["middle", undefined, undefined],
      ["too", "00:08.00", "00:09.00"],
    ],
  );
  assertEquals(store.data.video_length_seconds, 9);
  assertFalse(store.data.force_alignment_in_progress);
});

Deno.test("Gemini partial timestamps fail when a line boundary is missing", async () => {
  const response = {
    words: [
      { word: "First", start_seconds: 1, end_seconds: 2 },
      { word: "line" },
      { word: "Second", start_seconds: 3, end_seconds: 4 },
      { word: "line", start_seconds: 4, end_seconds: 5 },
    ],
  };
  const fallbackModel = queuedModel([response, response]);
  const { ctx, store } = makeCtx({
    data: { lyric_lines: ["First line", "Second line"] },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: () => Promise.reject(new Error("yt-dlp failed")),
  });

  await assertRejects(
    () => forceAlignment(ctx),
    Error,
    "Gemini did not timestamp the first and last words of transcript line 1",
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

Deno.test("non-YouTube URLs never reach Gemini and recover from checkpointed Scribe timings", async () => {
  const fallbackModel = queuedModel([]);
  const source = speechFixture(1, 2);
  const { ctx, store } = makeCtx({
    youtubeurl: TIKTOK_URL,
    data: {
      lyric_lines: ["Line one Line 2"],
      stt_candidates: { elevenlabs: { text: source.text, words: source.words } },
    },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: () => Promise.reject(new Error("TikTok audio unavailable")),
  });

  await forceAlignment(ctx);

  assertEquals(fallbackModel.calls(), 0);
  assertEquals(store.data.phrases?.[0].words.map((word) => word.text), [
    "Line",
    "one",
    "Line",
    "2",
  ]);
  assertFalse(store.data.force_alignment_in_progress);
});

Deno.test("YouTube uses checkpointed Scribe timings when Gemini also fails", async () => {
  const fallbackModel = queuedModel(["not-json", "still-not-json"]);
  const source = speechFixture(1, 1);
  const { ctx, store } = makeCtx({
    data: {
      lyric_lines: ["Line one"],
      stt_candidates: { elevenlabs: { text: source.text, words: source.words } },
    },
    models: { forceAlignmentFallback: fallbackModel.model },
    prepareAudio: () => Promise.reject(new Error("yt-dlp failed")),
  });

  await forceAlignment(ctx);

  assertEquals(fallbackModel.calls(), 2);
  assertEquals(store.data.phrases?.[0].words.map((word) => word.text), ["Line", "one"]);
  assertFalse(store.data.force_alignment_in_progress);
});
