import { assert, assertEquals, assertFalse } from "@std/assert";
import { runPipeline } from "../src/pipeline.ts";
import type { TriggerPayload } from "../src/types.ts";
import { MemorySink } from "../src/callback.ts";
import type { ModelRegistry } from "../src/models.ts";
import {
  alignedBatch,
  alignment,
  HEBREW,
  queuedModel,
  stubAlign,
  stubAudioWith,
  stubTranscribe,
  transcriptFixture,
  unusedModel,
} from "./helpers.ts";

const RATINGS = JSON.stringify([{ index: 1, title: "# Lesson", score: 4, reason: "ok" }]);
const noDictionary = () => Promise.resolve(null);

function payload(data: TriggerPayload["data"] = {}): TriggerPayload {
  return {
    youtubeurl: "https://www.youtube.com/watch?v=test123",
    clip_language: "French",
    clip_language_iso: "fr",
    translation_language: HEBREW,
    callback_url: "https://rails.example/cb",
    data,
  };
}

interface Mocks {
  lessons: ReturnType<typeof queuedModel>;
  rate: ReturnType<typeof queuedModel>;
  translate: ReturnType<typeof queuedModel>;
  tokens: ReturnType<typeof queuedModel>;
}

function happyMocks(overrides: Partial<Mocks> = {}): { mocks: Mocks; models: ModelRegistry } {
  const mocks: Mocks = {
    lessons: queuedModel([{
      lessons: [{ title: "Lesson", lines: ["Line 1", "Line 2"] }],
    }]),
    rate: queuedModel([RATINGS]),
    translate: queuedModel(["שורה 1\nשורה 2"]),
    tokens: queuedModel(["Line | ת1\n1 | ת2\nLine | ת3\n2 | ת4"]),
    ...overrides,
  };
  return {
    mocks,
    models: {
      extractLyrics: unusedModel().model,
      addLessons: mocks.lessons.model,
      rateLessons: mocks.rate.model,
      translate: mocks.translate.model,
      tokenTranslations: mocks.tokens.model,
    },
  };
}

function timingOptions() {
  return {
    prepareAudio: stubAudioWith(13),
    alignLyrics: stubAlign([alignment(alignedBatch(1, 2))]).align,
  };
}

Deno.test("a fresh Supadata run walks every step and finalizes translation", async () => {
  const { mocks, models } = happyMocks();
  const transcriber = stubTranscribe([transcriptFixture(1, 2)]);
  const sink = new MemorySink();
  const result = await runPipeline(payload(), {
    models,
    sink,
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
    transcribeVideo: transcriber.transcribe,
    ...timingOptions(),
  });

  assert(result.ok, JSON.stringify(result.failed));
  assertEquals(result.data.phrases!.length, 2);
  assertEquals(result.data.video_length_seconds, 13);
  assertEquals(result.data.lessons, "# Lesson\n00:00.00 Line 1\n00:10.00 Line 2");
  assertEquals(result.data.format_version, 2);
  assertEquals(result.data.translations!.he.phrases[0], {
    text: "שורה 1",
    words: ["ת1", "ת2"],
  });
  assertEquals(transcriber.calls(), 1);
  for (const mock of Object.values(mocks)) assertEquals(mock.calls(), 1);
  assert(sink.ops.some((op) => op.path === "phrases"));
});

Deno.test("failed native captions and Gemini fallback stop before downstream branches", async () => {
  const { mocks, models } = happyMocks();
  const transcriber = stubTranscribe([new Error("down"), new Error("down"), new Error("down")]);
  const result = await runPipeline(payload(), {
    models,
    sink: new MemorySink(),
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
    transcribeVideo: transcriber.transcribe,
  });

  assertFalse(result.ok);
  assert(result.failed.extract_lyrics);
  for (const mock of Object.values(mocks)) assertEquals(mock.calls(), 0);
});

Deno.test("rerunning saved data retries only the failed translation", async () => {
  const first = happyMocks({ translate: queuedModel(["only one line"]) });
  const firstRun = await runPipeline(payload(), {
    models: first.models,
    sink: new MemorySink(),
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
    transcribeVideo: stubTranscribe([transcriptFixture(1, 2)]).transcribe,
    ...timingOptions(),
  });
  assertFalse(firstRun.ok);

  const second = happyMocks({
    lessons: unusedModel(),
    rate: unusedModel(),
    tokens: unusedModel(),
  });
  const transcriber = stubTranscribe([]);
  const secondRun = await runPipeline(payload(firstRun.data), {
    models: second.models,
    sink: new MemorySink(),
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
    transcribeVideo: transcriber.transcribe,
  });

  assert(secondRun.ok, JSON.stringify(secondRun.failed));
  assertEquals(transcriber.calls(), 0);
  assertEquals(second.mocks.translate.calls(), 1);
  assertFalse(secondRun.data.errors?.some((error) => error.step === "translate") ?? false);
});

Deno.test("an interrupted transcription reruns Supadata despite partial phrases", async () => {
  const { models } = happyMocks();
  const transcriber = stubTranscribe([transcriptFixture(1, 2)]);
  const result = await runPipeline(
    payload({
      phrases: [{
        id: "phrase_1",
        text_l1: "Old partial line",
        timestamp: "00:00.00",
        timestamp_end: "00:02.00",
        words: [],
      }],
      extract_lyrics_in_progress: true,
    }),
    {
      models,
      sink: new MemorySink(),
      baseDelayMs: 0,
      fuzzywordFor: noDictionary,
      transcribeVideo: transcriber.transcribe,
      ...timingOptions(),
    },
  );

  assert(result.ok, JSON.stringify(result.failed));
  assertEquals(transcriber.calls(), 1);
  assertEquals(result.data.phrases!.length, 2);
});

Deno.test("without a translation language only lessons run after transcription", async () => {
  const { mocks, models } = happyMocks({ translate: unusedModel(), tokens: unusedModel() });
  const result = await runPipeline({ ...payload(), translation_language: null }, {
    models,
    sink: new MemorySink(),
    baseDelayMs: 0,
    fuzzywordFor: noDictionary,
    transcribeVideo: stubTranscribe([transcriptFixture(1, 2)]).transcribe,
    ...timingOptions(),
  });

  assert(result.ok);
  assert(result.data.lessons);
  assertEquals(result.data.translations, undefined);
  assertEquals(mocks.translate.calls(), 0);
  assertEquals(mocks.tokens.calls(), 0);
});
