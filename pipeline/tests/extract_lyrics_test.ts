import { assert, assertEquals, assertFalse, assertRejects } from "@std/assert";
import { extractLyrics, languageCodeForTranscription } from "../src/steps/extractLyrics.ts";
import { forceAlignment } from "../src/steps/forceAlignment.ts";
import {
  makeCtx,
  queuedModel,
  speechFixture,
  stubAudioWith,
  stubSpeechToTextFile,
  stubTranscribe,
  TIKTOK_URL,
  transcriptFixture,
} from "./helpers.ts";

Deno.test("reconciles conservatively while preserving ElevenLabs timings", async () => {
  const supadata = stubTranscribe([transcriptFixture(1, 2)]);
  const elevenlabs = stubSpeechToTextFile([speechFixture(1, 2)]);
  const sol = queuedModel([{ transcript: "Line one Line 2" }]);
  const { ctx, store } = makeCtx({
    transcribeVideo: supadata.transcribe,
    transcribeSpeechFile: elevenlabs.transcribe,
    prepareAudio: stubAudioWith(13),
    models: { reconcileTranscripts: sol.model },
  });

  await extractLyrics(ctx);

  assertEquals(supadata.calls(), 1);
  assertEquals(elevenlabs.calls(), 1);
  assertEquals(sol.calls(), 1);
  assertEquals(store.data.lyric_lines, ["Line one Line 2"]);
  assertEquals(store.data.stt_words, [
    { text: "Line", start: 0, end: 1 },
    { text: "one", start: 2, end: 3 },
    { text: "Line", start: 10, end: 11 },
    { text: "2", start: 12, end: 13 },
  ]);
  assertEquals(store.data.stt_candidates?.supadata?.text, "Line 1 Line 2");
  assertEquals(store.data.stt_candidates?.elevenlabs?.text, "Line 1 Line 2");
  assertFalse(store.data.extract_lyrics_in_progress);
});

Deno.test("falls back to complete ElevenLabs wording when Sol makes an unsafe rewrite", async () => {
  const { ctx, store } = makeCtx({
    transcribeVideo: stubTranscribe([transcriptFixture(1, 2)]).transcribe,
    transcribeSpeechFile: stubSpeechToTextFile([speechFixture(1, 2)]).transcribe,
    prepareAudio: stubAudioWith(13),
    models: {
      reconcileTranscripts: queuedModel([{
        transcript: "Completely rewritten transcript without shared anchors",
      }]).model,
    },
  });

  await extractLyrics(ctx);

  assertEquals(store.data.lyric_lines, ["Line 1 Line 2"]);
  assertEquals(store.data.stt_words, speechFixture(1, 2).words);
});

Deno.test("TikTok dual-source reconciliation reaches phrases without realignment or Gemini", async () => {
  let audioPreparations = 0;
  let alignments = 0;
  const gemini = queuedModel([]);
  const { ctx, store } = makeCtx({
    youtubeurl: TIKTOK_URL,
    transcribeVideo: stubTranscribe([transcriptFixture(1, 2)]).transcribe,
    transcribeSpeechFile: stubSpeechToTextFile([speechFixture(1, 2)]).transcribe,
    prepareAudio: async () => {
      audioPreparations++;
      return { path: "/tmp/langlets-test-audio.m4a", durationSeconds: 13 };
    },
    alignLyrics: () => {
      alignments++;
      throw new Error("forced alignment must not run");
    },
    models: {
      reconcileTranscripts: queuedModel([{ transcript: "Line one Line 2" }]).model,
      forceAlignmentFallback: gemini.model,
    },
  });

  await extractLyrics(ctx);
  await forceAlignment(ctx);

  assertEquals(audioPreparations, 1);
  assertEquals(alignments, 0);
  assertEquals(gemini.calls(), 0);
  assertEquals(store.data.phrases?.[0].words.map((word) => word.text), [
    "Line",
    "one",
    "Line",
    "2",
  ]);
});

Deno.test("uses Supadata alone and skips Sol when ElevenLabs fails", async () => {
  const supadata = stubTranscribe([transcriptFixture(1, 2)]);
  const elevenlabs = stubSpeechToTextFile([
    new Error("scribe down"),
    new Error("scribe down"),
    new Error("scribe down"),
  ]);
  const sol = queuedModel([]);
  const { ctx, store } = makeCtx({
    transcribeVideo: supadata.transcribe,
    transcribeSpeechFile: elevenlabs.transcribe,
    prepareAudio: stubAudioWith(13),
    models: { reconcileTranscripts: sol.model },
  });

  await extractLyrics(ctx);

  assertEquals(store.data.lyric_lines, ["Line 1 Line 2"]);
  assertEquals(store.data.stt_words, []);
  assertEquals(sol.calls(), 0);
});

Deno.test("uses ElevenLabs alone with its timings and skips Sol when Supadata fails", async () => {
  const supadata = stubTranscribe([new Error("captions unavailable")]);
  const elevenlabs = stubSpeechToTextFile([speechFixture(1, 2)]);
  const sol = queuedModel([]);
  const { ctx, store } = makeCtx({
    transcribeVideo: supadata.transcribe,
    transcribeSpeechFile: elevenlabs.transcribe,
    prepareAudio: stubAudioWith(13),
    models: { reconcileTranscripts: sol.model },
  });

  await extractLyrics(ctx);

  assertEquals(store.data.lyric_lines, ["Line 1 Line 2"]);
  assertEquals(store.data.stt_words?.length, 4);
  assertEquals(sol.calls(), 0);
});

Deno.test("YouTube uses Gemini only after both STT paths fail", async () => {
  const gemini = queuedModel(["First line\nSecond line"]);
  const { ctx, store } = makeCtx({
    transcribeVideo: stubTranscribe([new Error("captions unavailable")]).transcribe,
    transcribeSpeechFile: stubSpeechToTextFile([
      new Error("scribe down"),
      new Error("scribe down"),
      new Error("scribe down"),
    ]).transcribe,
    prepareAudio: stubAudioWith(13),
    models: { extractLyrics: gemini.model },
  });

  await extractLyrics(ctx);

  assertEquals(gemini.calls(), 1);
  assertEquals(store.data.lyric_lines, ["First line Second line"]);
});

Deno.test("TikTok fails when both STT paths fail and never calls Gemini", async () => {
  const gemini = queuedModel([]);
  const { ctx, store } = makeCtx({
    youtubeurl: TIKTOK_URL,
    transcribeVideo: stubTranscribe([new Error("captions unavailable")]).transcribe,
    transcribeSpeechFile: stubSpeechToTextFile([
      new Error("scribe down"),
      new Error("scribe down"),
      new Error("scribe down"),
    ]).transcribe,
    prepareAudio: stubAudioWith(13),
    models: { extractLyrics: gemini.model },
  });

  await assertRejects(
    () => extractLyrics(ctx),
    Error,
    "Supadata and ElevenLabs transcription both failed",
  );

  assertEquals(gemini.calls(), 0);
  assert(store.data.extract_lyrics_in_progress);
});

Deno.test("reuses a checkpointed candidate instead of calling that provider again", async () => {
  const supadata = stubTranscribe([]);
  const elevenlabs = stubSpeechToTextFile([speechFixture(1, 1)]);
  const sol = queuedModel([{ transcript: "Reconciled line" }]);
  const { ctx } = makeCtx({
    data: { stt_candidates: { supadata: { text: "Existing line" } } },
    transcribeVideo: supadata.transcribe,
    transcribeSpeechFile: elevenlabs.transcribe,
    prepareAudio: stubAudioWith(13),
    models: { reconcileTranscripts: sol.model },
  });

  await extractLyrics(ctx);

  assertEquals(supadata.calls(), 0);
  assertEquals(elevenlabs.calls(), 1);
  assertEquals(sol.calls(), 1);
});

Deno.test("falls back to ElevenLabs when Sol reconciliation fails", async () => {
  const sol = queuedModel(["not-json", "still-not-json"]);
  const { ctx, store } = makeCtx({
    transcribeVideo: stubTranscribe([transcriptFixture(1, 1)]).transcribe,
    transcribeSpeechFile: stubSpeechToTextFile([speechFixture(1, 1)]).transcribe,
    prepareAudio: stubAudioWith(13),
    models: { reconcileTranscripts: sol.model },
  });

  await extractLyrics(ctx);

  assertEquals(store.data.lyric_lines, ["Line 1"]);
  assertEquals(store.data.stt_words?.length, 2);
});

Deno.test("maps explicit and named clip languages to transcription codes", () => {
  assertEquals(languageCodeForTranscription("French"), "fr");
  assertEquals(languageCodeForTranscription("French", "fr-CA"), "fr-CA");
  assertEquals(languageCodeForTranscription("Unknown"), null);
});
