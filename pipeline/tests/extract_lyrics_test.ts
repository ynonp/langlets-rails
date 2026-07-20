import { assert, assertEquals, assertFalse, assertRejects } from "@std/assert";
import { extractLyrics } from "../src/steps/extractLyrics.ts";
import { lyricsText, makeCtx, queuedModel } from "./helpers.ts";

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

Deno.test("gives up after retries and records the response in data.errors", async () => {
  const model = queuedModel(["", "  ", "```\n```"]);
  const { ctx, store } = makeCtx({ models: { extractLyrics: model.model } });

  await assertRejects(() => extractLyrics(ctx));
  assertEquals(model.calls(), 3);

  const error = store.data.errors![0];
  assertEquals(error.step, "extract_lyrics");
  assertEquals(error.attempts, 3);
  // The unusable response is inspectable.
  assertEquals(error.agent_response, "```\n```");
  // The interrupted flag survives so the next run resumes the step.
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
