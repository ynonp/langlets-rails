import { assert, assertEquals, assertFalse } from "@std/assert";
import { runPipeline } from "../src/pipeline.ts";
import type { TriggerPayload } from "../src/types.ts";
import { MemorySink } from "../src/callback.ts";
import type { ModelRegistry } from "../src/models.ts";
import {
  alignedBatch,
  alignment,
  geminiAlignment,
  HEBREW,
  lyricsText,
  queuedModel,
  stubAlign,
  stubAudio,
  unusedModel,
} from "./helpers.ts";

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
  // Backup aligner: unused whenever the ElevenLabs stub succeeds.
  align: ReturnType<typeof queuedModel>;
  lessons: ReturnType<typeof queuedModel>;
  rate: ReturnType<typeof queuedModel>;
  translate: ReturnType<typeof queuedModel>;
  tokens: ReturnType<typeof queuedModel>;
}

function happyMocks(overrides: Partial<Mocks> = {}): { mocks: Mocks; models: ModelRegistry } {
  const mocks: Mocks = {
    extract: queuedModel([lyricsText(1, 2)]),
    align: unusedModel(),
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
      forceAlignment: mocks.align.model,
      addLessons: mocks.lessons.model,
      rateLessons: mocks.rate.model,
      translate: mocks.translate.model,
      tokenTranslations: mocks.tokens.model,
    },
  };
}

// An aligner that times the two-line lyrics fixture (clip duration comes from
// stubAudio: 15s).
function happyAligner() {
  return stubAlign([alignment(alignedBatch(1, 2))]);
}

Deno.test("a fresh run walks every step and finalizes the translation payload", async () => {
  const { mocks, models } = happyMocks();
  const aligner = happyAligner();
  const sink = new MemorySink();

  const result = await runPipeline(payload(), {
    models,
    sink,
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
    prepareAudio: stubAudio,
    alignLyrics: aligner.align,
  });

  assert(result.ok, JSON.stringify(result.failed));
  const data = result.data;

  assertEquals(data.phrases!.length, 2);
  assertFalse(data.extract_lyrics_in_progress);
  assertEquals(data.video_length_seconds, 15);
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

  assertEquals(aligner.calls(), 1);
  // ElevenLabs did the timing, so the Gemini backup was never needed.
  assertEquals(mocks.align.calls(), 0);
  for (const [name, mock] of Object.entries(mocks)) {
    if (name !== "align") assertEquals(mock.calls(), 1, name);
  }
  // Every mutation also went out through the callback sink.
  assert(sink.ops.some((op) => op.path === "phrases"));
  assert(sink.ops.some((op) => op.path === "lessons"));
});

Deno.test("lessons and sentence translation start while force alignment is running", async () => {
  const { mocks, models } = happyMocks();
  let alignmentStarted = false;
  let releaseAlignment!: () => void;
  const lessonStarted = new Promise<void>((resolve) => (releaseAlignment = resolve));
  let releaseTranslation!: () => void;
  const translationStarted = new Promise<void>((resolve) => (releaseTranslation = resolve));
  const baseLessonsModel = mocks.lessons.model as unknown as {
    doGenerate(options: unknown): Promise<unknown>;
  };

  models.addLessons = Object.assign({}, mocks.lessons.model as object, {
    doGenerate(options: unknown) {
      assert(alignmentStarted, "lesson generation should start after alignment was launched");
      releaseAlignment();
      return baseLessonsModel.doGenerate(options);
    },
  }) as unknown as typeof models.addLessons;

  const baseTranslateModel = mocks.translate.model as unknown as {
    doGenerate(options: unknown): Promise<unknown>;
  };
  models.translate = Object.assign({}, mocks.translate.model as object, {
    doGenerate(options: unknown) {
      assert(alignmentStarted, "translation should start after alignment was launched");
      releaseTranslation();
      return baseTranslateModel.doGenerate(options);
    },
  }) as unknown as typeof models.translate;

  const alignLyrics = async () => {
    alignmentStarted = true;
    await Promise.all([lessonStarted, translationStarted]);
    return alignment(alignedBatch(1, 2));
  };

  const result = await runPipeline(payload(), {
    models,
    sink: new MemorySink(),
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
    prepareAudio: stubAudio,
    alignLyrics,
  });

  assert(result.ok, JSON.stringify(result.failed));
  assertEquals(result.data.lessons, "# Lesson\n00:00.00 Line 1\n00:10.00 Line 2");
});

Deno.test("token translation starts after alignment without waiting for lessons", async () => {
  const { mocks, models } = happyMocks();
  let releaseLessons!: () => void;
  const tokenStarted = new Promise<void>((resolve) => (releaseLessons = resolve));

  const baseLessonsModel = mocks.lessons.model as unknown as {
    doGenerate(options: unknown): Promise<unknown>;
  };
  models.addLessons = Object.assign({}, mocks.lessons.model as object, {
    async doGenerate(options: unknown) {
      await tokenStarted;
      return await baseLessonsModel.doGenerate(options);
    },
  }) as unknown as typeof models.addLessons;

  const baseTokensModel = mocks.tokens.model as unknown as {
    doGenerate(options: unknown): Promise<unknown>;
  };
  models.tokenTranslations = Object.assign({}, mocks.tokens.model as object, {
    doGenerate(options: unknown) {
      releaseLessons();
      return baseTokensModel.doGenerate(options);
    },
  }) as unknown as typeof models.tokenTranslations;

  const result = await runPipeline(payload(), {
    models,
    sink: new MemorySink(),
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
    prepareAudio: stubAudio,
    alignLyrics: happyAligner().align,
  });

  assert(result.ok, JSON.stringify(result.failed));
  assertEquals(mocks.tokens.calls(), 1);
  assertEquals(mocks.lessons.calls(), 1);
});

Deno.test("a force_alignment failure keeps parallel lesson work but stops downstream", async () => {
  // ElevenLabs is down and the Gemini backup has no response queued either.
  const { mocks, models } = happyMocks();
  const aligner = stubAlign([
    new Error("bad"),
    new Error("bad"),
    new Error("bad"),
  ]);

  const result = await runPipeline(payload(), {
    models,
    sink: new MemorySink(),
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
    prepareAudio: stubAudio,
    alignLyrics: aligner.align,
  });

  assertFalse(result.ok);
  assert(result.failed.force_alignment);
  // The transcription itself survived, so a rerun only retries the timing.
  assertEquals(result.data.lyric_lines, ["Line 1", "Line 2"]);
  assertEquals(mocks.lessons.calls(), 1);
  assertEquals(mocks.rate.calls(), 1);
  assertEquals(result.data.lesson_outline, "# Lesson\nLine 1\nLine 2");
  assertEquals(result.data.lessons, undefined);
  assertEquals(mocks.translate.calls(), 1);
  assertEquals(result.data.translation_lines!.he, ["שורה 1", "שורה 2"]);
  assertEquals(mocks.tokens.calls(), 0);
});

Deno.test("the Gemini backup times the lyrics when ElevenLabs fails", async () => {
  const { mocks, models } = happyMocks({ align: queuedModel([geminiAlignment(1, 2)]) });
  const aligner = stubAlign([new Error("bad"), new Error("bad"), new Error("bad")]);

  const result = await runPipeline(payload(), {
    models,
    sink: new MemorySink(),
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
    prepareAudio: stubAudio,
    alignLyrics: aligner.align,
  });

  assert(result.ok, JSON.stringify(result.failed));
  assertEquals(mocks.align.calls(), 1);
  assertEquals(result.data.phrases!.map((p) => p.text_l1), ["Line 1", "Line 2"]);
  // The run carried on into the fan-out on the backup's timings.
  assert(result.data.lessons);
  assertEquals(result.data.translations!.he.phrases[0].text, "שורה 1");
});

Deno.test("a failing branch doesn't lose the other branches' work", async () => {
  const { mocks, models } = happyMocks({
    // translate has no retries: a single bad response fails the branch.
    translate: queuedModel(["only one line"]),
  });

  const result = await runPipeline(payload(), {
    models,
    sink: new MemorySink(),
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
    prepareAudio: stubAudio,
    alignLyrics: happyAligner().align,
  });

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
    prepareAudio: stubAudio,
    alignLyrics: happyAligner().align,
  });
  assertFalse(firstRun.ok);

  // Second trigger, same exported data — as create_data would send it.
  const second = happyMocks({
    extract: unusedModel(),
    lessons: unusedModel(),
    rate: unusedModel(),
    tokens: unusedModel(),
  });
  const secondAligner = stubAlign([]);
  const secondRun = await runPipeline(payload(firstRun.data), {
    models: second.models,
    sink: new MemorySink(),
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
    prepareAudio: stubAudio,
    alignLyrics: secondAligner.align,
  });

  assert(secondRun.ok, JSON.stringify(secondRun.failed));
  assertEquals(second.mocks.translate.calls(), 1);
  assertEquals(second.mocks.extract.calls(), 0);
  assertEquals(secondAligner.calls(), 0);
  assertEquals(second.mocks.lessons.calls(), 0);
  assertEquals(second.mocks.rate.calls(), 0);
  assertEquals(second.mocks.tokens.calls(), 0);

  const payload_he = secondRun.data.translations!.he;
  assertEquals(payload_he.phrases[0], { text: "שורה 1", words: ["ת1", "ת2"] });
  assertEquals(payload_he.lessons, secondRun.data.lessons);
  assertFalse(secondRun.data.errors?.some((error) => error.step === "translate") ?? false);
});

Deno.test("an interrupted transcription resumes extract_lyrics on the next run", async () => {
  const { mocks, models } = happyMocks();
  const aligner = happyAligner();
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

  const result = await runPipeline(payload(data), {
    models,
    sink: new MemorySink(),
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
    prepareAudio: stubAudio,
    alignLyrics: aligner.align,
  });

  assert(result.ok, JSON.stringify(result.failed));
  // The step reran (the flag said "interrupted", despite phrases being present).
  assertEquals(mocks.extract.calls(), 1);
  assertEquals(aligner.calls(), 1);
});

Deno.test("without a translation language only the lessons branch runs after extract", async () => {
  const { mocks, models } = happyMocks({
    translate: unusedModel(),
    tokens: unusedModel(),
  });

  const result = await runPipeline(
    { ...payload(), translation_language: null },
    {
      models,
      sink: new MemorySink(),
      baseDelayMs: 0,
      fuzzywordFor: noDictionary,
      prepareAudio: stubAudio,
      alignLyrics: happyAligner().align,
    },
  );

  assert(result.ok);
  assert(result.data.lessons);
  assertEquals(result.data.translations, undefined);
  assertEquals(mocks.translate.calls(), 0);
  assertEquals(mocks.tokens.calls(), 0);
});
