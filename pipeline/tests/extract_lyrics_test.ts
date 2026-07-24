import { assert, assertEquals, assertFalse, assertRejects } from "@std/assert";
import { extractLyrics, languageCodeForTranscription } from "../src/steps/extractLyrics.ts";
import {
  makeCtx,
  queuedModel,
  speechFixture,
  stubSpeechToText,
  stubTranscribe,
  TIKTOK_URL,
  transcriptFixture,
} from "./helpers.ts";

Deno.test("saves continuous Supadata transcript text for alignment", async () => {
  const transcriber = stubTranscribe([transcriptFixture(1, 2)]);
  const { ctx, store } = makeCtx({ transcribeVideo: transcriber.transcribe });

  await extractLyrics(ctx);

  assertEquals(store.data.lyric_lines, ["Line 1 Line 2"]);
  assertEquals(store.data.phrases, undefined);
  assertFalse(store.data.extract_lyrics_in_progress);
  assert(store.data.force_alignment_in_progress);
  assertEquals(transcriber.requests[0].languageCode, "fr");
});

Deno.test("falls back to Gemini immediately when YouTube native captions fail", async () => {
  const transcriber = stubTranscribe([new Error("transcript-unavailable")]);
  const gemini = queuedModel(["First line\nSecond line"]);
  const { ctx, store } = makeCtx({
    transcribeVideo: transcriber.transcribe,
    models: { extractLyrics: gemini.model },
  });

  await extractLyrics(ctx);

  assertEquals(transcriber.calls(), 1);
  assertEquals(gemini.calls(), 1);
  assertEquals(store.data.lyric_lines, ["First line Second line"]);
});

Deno.test("does not use Gemini fallback for a non-YouTube provider", async () => {
  const transcriber = stubTranscribe([new Error("Supadata unavailable")]);
  const { ctx, store } = makeCtx({ transcribeVideo: transcriber.transcribe });
  ctx.youtubeurl = "https://vimeo.com/123";

  await assertRejects(() => extractLyrics(ctx), Error, "Supadata unavailable");

  assert(store.data.extract_lyrics_in_progress);
  assert(store.data.force_alignment_in_progress);
  assertEquals(store.data.errors![0].step, "extract_lyrics");
  assertEquals(store.data.errors![0].attempts, undefined);
});

Deno.test("a successful rerun clears only transcription errors", async () => {
  const { ctx, store } = makeCtx({
    data: {
      errors: [
        { step: "extract_lyrics", occurred_at: "2024-01-01", error_message: "old" },
        { step: "force_alignment", occurred_at: "2024-01-01", error_message: "old" },
      ],
    },
    transcribeVideo: stubTranscribe([transcriptFixture(1, 1)]).transcribe,
  });

  await extractLyrics(ctx);

  assertEquals(store.data.errors?.map((error) => error.step), ["force_alignment"]);
});

Deno.test("maps explicit and named clip languages to Supadata codes", () => {
  assertEquals(languageCodeForTranscription("French"), "fr");
  assertEquals(languageCodeForTranscription("French", "fr-CA"), "fr-CA");
  assertEquals(languageCodeForTranscription("Unknown"), null);
});

Deno.test("TikTok transcribes with ElevenLabs speech-to-text instead of Supadata", async () => {
  const supadata = stubTranscribe([transcriptFixture(1, 2)]);
  const speech = stubSpeechToText([speechFixture(1, 2)]);
  const { ctx, store } = makeCtx({
    youtubeurl: TIKTOK_URL,
    transcribeVideo: supadata.transcribe,
    transcribeSpeech: speech.transcribe,
    clipLanguage: "Spanish",
  });

  await extractLyrics(ctx);

  assertEquals(supadata.calls(), 0);
  assertEquals(speech.calls(), 1);
  assertEquals(speech.requests[0], { sourceUrl: TIKTOK_URL, languageCode: "es" });
  assertEquals(store.data.lyric_lines, ["Line 1 Line 2"]);
  assertFalse(store.data.extract_lyrics_in_progress);
});

Deno.test("TikTok stashes timed words so force_alignment has nothing left to align", async () => {
  const speech = stubSpeechToText([speechFixture(1, 2)]);
  const { ctx, store } = makeCtx({
    youtubeurl: TIKTOK_URL,
    transcribeSpeech: speech.transcribe,
  });

  await extractLyrics(ctx);

  assertEquals(store.data.stt_words?.length, 4);
  assertEquals(store.data.stt_words?.[0], { text: "Line", start: 0, end: 1 });
  // Deliberately left true: force_alignment still has to run to turn these
  // words into the provisional phrase, it just won't download any audio.
  assert(store.data.force_alignment_in_progress);
});

Deno.test("TikTok never falls back to Gemini — a failed transcription fails the step", async () => {
  const speech = stubSpeechToText([
    new Error("scribe-unavailable"),
    new Error("scribe-unavailable"),
    new Error("scribe-unavailable"),
  ]);
  const gemini = queuedModel(["Should not be used"]);
  const { ctx, store } = makeCtx({
    youtubeurl: TIKTOK_URL,
    transcribeSpeech: speech.transcribe,
    models: { extractLyrics: gemini.model },
  });

  await assertRejects(() => extractLyrics(ctx), Error, "scribe-unavailable");

  assertEquals(gemini.calls(), 0);
  assertEquals(store.data.errors![0].step, "extract_lyrics");
});
