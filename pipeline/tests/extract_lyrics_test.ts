import { assert, assertEquals, assertFalse, assertRejects } from "@std/assert";
import { extractLyrics } from "../src/steps/extractLyrics.ts";
import { lyricsText, makeCtx, queuedModel, stubAudioWith } from "./helpers.ts";

Deno.test("saves the Gemini transcription as lyric lines", async () => {
  const model = queuedModel(["First line\nSecond line"]);
  const { ctx, store } = makeCtx({ models: { extractLyrics: model.model } });

  await extractLyrics(ctx);

  assertEquals(store.data.lyric_lines, ["First line", "Second line"]);
  assertFalse(store.data.extract_lyrics_in_progress);
  assertEquals(model.calls(), 1);
  // Timing hasn't happened yet, so the step leaves alignment marked unfinished.
  assert(store.data.force_alignment_in_progress);
  // Nothing here writes phrases — that's force_alignment's job.
  assertEquals(store.data.phrases, undefined);
});

Deno.test("strips markdown fences and blank lines from the response", async () => {
  const model = queuedModel(["```\nLine 1\n\n  Line 2  \n```"]);
  const { ctx, store } = makeCtx({ models: { extractLyrics: model.model } });

  await extractLyrics(ctx);

  assertEquals(store.data.lyric_lines, ["Line 1", "Line 2"]);
});

Deno.test("retries a lyrics response with no usable lines", async () => {
  const model = queuedModel(["```\n```", lyricsText(1, 2)]);
  const { ctx, store } = makeCtx({ models: { extractLyrics: model.model } });

  await extractLyrics(ctx);

  assertEquals(store.data.lyric_lines!.length, 2);
  assertEquals(model.calls(), 2);
});

Deno.test("gives up after retries and falls back to STT, fails when STT also fails", async () => {
  const model = queuedModel(["", "  ", "```\n```"]);
  const { ctx, store } = makeCtx({
    models: { extractLyrics: model.model },
    transcribeAudio: () => Promise.reject(new Error("ELEVEN_LABS_KEY is not set")),
  });

  await assertRejects(() => extractLyrics(ctx), Error, "ELEVEN_LABS_KEY");
  assertEquals(model.calls(), 3);

  const error = store.data.errors![0];
  assertEquals(error.step, "extract_lyrics");
  // The unusable Gemini response is inspectable.
  assertEquals(error.agent_response, "```\n```");
  // The interrupted flag survives so the next run resumes the step.
  assert(store.data.extract_lyrics_in_progress);
});

Deno.test("falls back to STT when Gemini returns no usable lines", async () => {
  const model = queuedModel(["```\n```"]); // Gemini returns empty
  const sttResult = { text: "Hello world. How are you?", language_code: "en" };
  const { ctx, store } = makeCtx({
    models: { extractLyrics: model.model },
    transcribeAudio: () => Promise.resolve(sttResult),
    prepareAudio: stubAudioWith(20),
  });

  await extractLyrics(ctx);

  // STT lines were saved.
  assertEquals(store.data.lyric_lines, ["Hello world.", "How are you?"]);
  assertFalse(store.data.extract_lyrics_in_progress);
  assert(store.data.force_alignment_in_progress);
  // Gemini was called once, then STT took over.
  assertEquals(model.calls(), 1);
});

Deno.test("fails when both Gemini and STT produce no usable lines", async () => {
  const model = queuedModel(["```\n```"]);
  const { ctx, store } = makeCtx({
    models: { extractLyrics: model.model },
    transcribeAudio: () => Promise.resolve({ text: "", language_code: "en" }),
    prepareAudio: stubAudioWith(20),
  });

  await assertRejects(
    () => extractLyrics(ctx),
    Error,
    "STT fallback produced no usable lines",
  );

  const error = store.data.errors![0];
  assertEquals(error.step, "extract_lyrics");
  assert(store.data.extract_lyrics_in_progress);
});

Deno.test("a successful rerun clears the step's earlier errors", async () => {
  const model = queuedModel([lyricsText(1, 2)]);
  const { ctx, store } = makeCtx({
    data: {
      errors: [{
        step: "extract_lyrics",
        occurred_at: "2024-01-01T00:00:00Z",
        error_message: "old failure",
      }],
    },
    models: { extractLyrics: model.model },
  });

  await extractLyrics(ctx);

  assertEquals(store.data.errors, []);
});
