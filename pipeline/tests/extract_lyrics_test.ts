import { assert, assertEquals, assertFalse, assertRejects } from "@std/assert";
import { extractLyrics, languageCodeForTranscription } from "../src/steps/extractLyrics.ts";
import { makeCtx, stubTranscribe, transcriptFixture } from "./helpers.ts";

Deno.test("saves split Supadata transcript text for alignment", async () => {
  const transcriber = stubTranscribe([transcriptFixture(1, 2)]);
  const { ctx, store } = makeCtx({ transcribeVideo: transcriber.transcribe });

  await extractLyrics(ctx);

  assertEquals(store.data.lyric_lines, ["Line 1", "Line 2"]);
  assertEquals(store.data.phrases, undefined);
  assertFalse(store.data.extract_lyrics_in_progress);
  assert(store.data.force_alignment_in_progress);
  assertEquals(transcriber.requests[0].languageCode, "fr");
});

Deno.test("retries Supadata failures", async () => {
  const transcriber = stubTranscribe([new Error("temporary"), transcriptFixture(1, 1)]);
  const { ctx, store } = makeCtx({ transcribeVideo: transcriber.transcribe });

  await extractLyrics(ctx);

  assertEquals(transcriber.calls(), 2);
  assertEquals(store.data.lyric_lines, ["Line 1"]);
});

Deno.test("records a Supadata failure and leaves resume flags set", async () => {
  const transcriber = stubTranscribe([
    new Error("Supadata unavailable"),
    new Error("Supadata unavailable"),
    new Error("Supadata unavailable"),
  ]);
  const { ctx, store } = makeCtx({ transcribeVideo: transcriber.transcribe });

  await assertRejects(() => extractLyrics(ctx), Error, "Supadata unavailable");

  assert(store.data.extract_lyrics_in_progress);
  assert(store.data.force_alignment_in_progress);
  assertEquals(store.data.errors![0].step, "extract_lyrics");
  assertEquals(store.data.errors![0].attempts, 3);
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
