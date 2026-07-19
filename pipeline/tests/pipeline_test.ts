import { assert, assertEquals, assertFalse } from "@std/assert";
import { runPipeline } from "../src/pipeline.ts";
import type { TriggerPayload } from "../src/types.ts";
import { MemorySink } from "../src/callback.ts";
import type { ModelRegistry } from "../src/models.ts";
import { HEBREW, linesBatch, queuedModel, unusedModel } from "./helpers.ts";

const RATINGS = JSON.stringify([{ index: 1, title: "# Lesson", score: 4, reason: "ok" }]);

// No similar-sound dictionary in pipeline tests: the step falls back to
// passing lines through unchanged, which keeps runs deterministic.
const noDictionary = () => Promise.resolve(null);

function payload(data: TriggerPayload["data"] = {}): TriggerPayload {
  return {
    youtubeurl: "https://www.youtube.com/watch?v=test123",
    clip_language: "French",
    translation_language: HEBREW,
    callback_url: "https://rails.example/cb",
    data,
  };
}

interface Mocks {
  extract: ReturnType<typeof queuedModel>;
  lessons: ReturnType<typeof queuedModel>;
  rate: ReturnType<typeof queuedModel>;
  translate: ReturnType<typeof queuedModel>;
  tokens: ReturnType<typeof queuedModel>;
}

function happyMocks(overrides: Partial<Mocks> = {}): { mocks: Mocks; models: ModelRegistry } {
  const mocks: Mocks = {
    extract: queuedModel([
      { lines: linesBatch(1, 2), has_more: false, video_length: "00:00:15,000" },
    ]),
    lessons: queuedModel(["# Lesson\nLine 1\nLine 2"]),
    rate: queuedModel([RATINGS]),
    translate: queuedModel(["שורה 1\nשורה 2"]),
    tokens: queuedModel(["a | ת1\nb | ת2\nc | ת3\nd | ת4"]),
    ...overrides,
  };

  return {
    mocks,
    models: {
      extractLyrics: mocks.extract.model,
      addLessons: mocks.lessons.model,
      rateLessons: mocks.rate.model,
      translate: mocks.translate.model,
      tokenTranslations: mocks.tokens.model,
    },
  };
}

Deno.test("a fresh run walks every step and finalizes the translation payload", async () => {
  const { mocks, models } = happyMocks();
  const sink = new MemorySink();

  const result = await runPipeline(payload(), {
    models,
    sink,
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
  });

  assert(result.ok, JSON.stringify(result.failed));
  const data = result.data;

  assertEquals(data.phrases!.length, 2);
  assertFalse(data.extract_lyrics_in_progress);
  assertEquals(data.lessons, "# Lesson\n00:00.00 Line 1\n00:10.00 Line 2");
  assertEquals(data.lesson_ratings!.length, 1);
  assertEquals(data.format_version, 2);
  // Similar sounds ran in the fan-out; without a dictionary the lines pass
  // through unchanged.
  assertEquals(data.similar_sounds, "Line 1\nLine 2");

  const payload_he = data.translations!.he;
  assertEquals(payload_he.language_id, 3);
  assertEquals(payload_he.language_name, "Hebrew");
  assertEquals(payload_he.phrases[0], { text: "שורה 1", words: ["ת1", "ת2"] });
  assertEquals(payload_he.phrases[1], { text: "שורה 2", words: ["ת3", "ת4"] });
  // The clip-language lessons snapshot lands in the payload at finalize time.
  assertEquals(payload_he.lessons, data.lessons);

  for (const mock of Object.values(mocks)) assertEquals(mock.calls(), 1);
  // Every mutation also went out through the callback sink.
  assert(sink.ops.some((op) => op.path === "phrases"));
  assert(sink.ops.some((op) => op.path === "lessons"));
});

Deno.test("an extract_lyrics failure stops the run before the fan-out", async () => {
  const { mocks, models } = happyMocks({
    extract: queuedModel(["bad", "bad", "bad"]),
  });

  const result = await runPipeline(payload(), { models, sink: new MemorySink(), baseDelayMs: 0, fuzzywordFor: noDictionary });

  assertFalse(result.ok);
  assert(result.failed.extract_lyrics);
  assertEquals(mocks.lessons.calls(), 0);
  assertEquals(mocks.translate.calls(), 0);
  assertEquals(mocks.tokens.calls(), 0);
});

Deno.test("a failing branch doesn't lose the other branches' work", async () => {
  const { mocks, models } = happyMocks({
    // translate has no retries: a single bad response fails the branch.
    translate: queuedModel(["only one line"]),
  });

  const result = await runPipeline(payload(), { models, sink: new MemorySink(), baseDelayMs: 0, fuzzywordFor: noDictionary });

  assertFalse(result.ok);
  assertEquals(Object.keys(result.failed), ["translate"]);

  // Lessons and token translations completed and persisted.
  assert(result.data.lessons);
  assertEquals(result.data.lesson_ratings!.length, 1);
  assertEquals(result.data.translations!.he.phrases[0].words, ["ת1", "ת2"]);
  // Finalize was skipped: the payload isn't stamped complete.
  assertEquals(result.data.translations!.he.lessons, null);
  // The failed LLM response is inspectable.
  const error = result.data.errors!.find((e) => e.step === "translate")!;
  assertEquals(error.agent_response, "only one line");
  assertEquals(mocks.tokens.calls(), 1);
});

Deno.test("rerunning with the saved data retries only what failed", async () => {
  const first = happyMocks({ translate: queuedModel(["only one line"]) });
  const firstRun = await runPipeline(payload(), {
    models: first.models,
    sink: new MemorySink(),
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
  });
  assertFalse(firstRun.ok);

  // Second trigger, same exported data — as create_data would send it.
  const second = happyMocks({
    extract: unusedModel(),
    lessons: unusedModel(),
    rate: unusedModel(),
    tokens: unusedModel(),
  });
  const secondRun = await runPipeline(payload(firstRun.data), {
    models: second.models,
    sink: new MemorySink(),
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
  });

  assert(secondRun.ok, JSON.stringify(secondRun.failed));
  assertEquals(second.mocks.translate.calls(), 1);
  assertEquals(second.mocks.extract.calls(), 0);
  assertEquals(second.mocks.lessons.calls(), 0);
  assertEquals(second.mocks.rate.calls(), 0);
  assertEquals(second.mocks.tokens.calls(), 0);

  const payload_he = secondRun.data.translations!.he;
  assertEquals(payload_he.phrases[0], { text: "שורה 1", words: ["ת1", "ת2"] });
  assertEquals(payload_he.lessons, secondRun.data.lessons);
});

Deno.test("an interrupted transcription resumes extract_lyrics on the next run", async () => {
  const { mocks, models } = happyMocks();
  const data = {
    phrases: [
      {
        id: "phrase_1",
        text_l1: "Old partial line",
        timestamp: "00:00.00",
        timestamp_end: "00:02.00",
        words: [],
      },
    ],
    extract_lyrics_in_progress: true,
  };

  const result = await runPipeline(payload(data), { models, sink: new MemorySink(), baseDelayMs: 0, fuzzywordFor: noDictionary });

  assert(result.ok, JSON.stringify(result.failed));
  // The step reran (the flag said "interrupted", despite phrases being present).
  assertEquals(mocks.extract.calls(), 1);
});

Deno.test("without a translation language only the lessons branch runs after extract", async () => {
  const { mocks, models } = happyMocks({
    translate: unusedModel(),
    tokens: unusedModel(),
  });

  const result = await runPipeline(
    { ...payload(), translation_language: null },
    { models, sink: new MemorySink(), baseDelayMs: 0, fuzzywordFor: noDictionary },
  );

  assert(result.ok);
  assert(result.data.lessons);
  assertEquals(result.data.translations, undefined);
  assertEquals(mocks.translate.calls(), 0);
  assertEquals(mocks.tokens.calls(), 0);
});
