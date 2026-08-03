import { assert, assertEquals, assertFalse, assertRejects } from "@std/assert";
import { extractLyrics, languageCodeForTranscription } from "../src/steps/extractLyrics.ts";
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

Deno.test("runs Supadata and downloaded-audio ElevenLabs then reconciles with Sol", async () => {
  const supadata = stubTranscribe([transcriptFixture(1, 2)]);
  const elevenlabs = stubSpeechToTextFile([speechFixture(1, 2)]);
  const sol = queuedModel([{ transcript: "Corrected line one and line two" }]);
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
  assertEquals(store.data.lyric_lines, ["Corrected line one and line two"]);
  assertEquals(store.data.stt_words, []);
  assertEquals(store.data.stt_candidates?.supadata?.text, "Line 1 Line 2");
  assertEquals(store.data.stt_candidates?.elevenlabs?.text, "Line 1 Line 2");
  assertFalse(store.data.extract_lyrics_in_progress);
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
