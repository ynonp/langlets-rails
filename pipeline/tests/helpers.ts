// Shared test scaffolding: queued mock language models and a PipelineContext
// factory wired to an in-memory sink. The mock implements the LanguageModelV2
// spec by hand instead of using `ai/test`, whose MockLanguageModelV2 drags in
// msw (an npm devDependency Deno can't resolve).

import type { LanguageModel } from "ai";
import type { LanguageRef, ProgressData } from "../src/types.ts";
import { MemorySink } from "../src/callback.ts";
import { ProgressStore } from "../src/progress.ts";
import type { ModelRegistry } from "../src/models.ts";
import type { PipelineContext } from "../src/context.ts";

export interface QueuedModel {
  model: LanguageModel;
  calls: () => number;
  // The full prompt (message array) each call received.
  prompts: unknown[][];
}

// A model that answers from a queue: strings are returned verbatim (also how
// we simulate truncated/unparsable structured output), objects are
// JSON-stringified. Throws once the queue is exhausted.
export function queuedModel(responses: Array<string | object>): QueuedModel {
  let count = 0;
  const prompts: unknown[][] = [];

  const model = {
    specificationVersion: "v2",
    provider: "mock",
    modelId: "mock-model",
    // Claim support for every URL so generateText never tries to download the
    // YouTube file part during tests.
    supportedUrls: { "*": [/.*/] },
    doStream: () => Promise.reject(new Error("streaming not mocked")),
    // deno-lint-ignore no-explicit-any
    doGenerate: (options: any) => {
      prompts.push(options.prompt);
      if (count >= responses.length) throw new Error("mock model exhausted");
      const next = responses[count++];
      const text = typeof next === "string" ? next : JSON.stringify(next);
      return Promise.resolve({
        finishReason: "stop",
        usage: { inputTokens: 1, outputTokens: 1, totalTokens: 2 },
        content: [{ type: "text", text }],
        warnings: [],
      });
    },
  } as unknown as LanguageModel;

  return { model, calls: () => count, prompts };
}

export function unusedModel(): QueuedModel {
  return queuedModel([]);
}

export const HEBREW: LanguageRef = { id: 3, iso_name: "he", english_name: "Hebrew" };

export interface TestSetup {
  ctx: PipelineContext;
  store: ProgressStore;
  sink: MemorySink;
}

export function makeCtx(options: {
  data?: ProgressData;
  models?: Partial<ModelRegistry>;
  translationLanguage?: LanguageRef | null;
  clipLanguage?: string;
} = {}): TestSetup {
  const sink = new MemorySink();
  const store = new ProgressStore(options.data ?? {}, sink);

  const models: ModelRegistry = {
    extractLyrics: unusedModel().model,
    addLessons: unusedModel().model,
    rateLessons: unusedModel().model,
    translate: unusedModel().model,
    tokenTranslations: unusedModel().model,
    ...options.models,
  };

  const ctx: PipelineContext = {
    store,
    models,
    youtubeurl: "https://www.youtube.com/watch?v=test123",
    clipLanguage: options.clipLanguage ?? "French",
    translationLanguage: options.translationLanguage === undefined
      ? HEBREW
      : options.translationLanguage,
    baseDelayMs: 0,
  };

  return { ctx, store, sink };
}

// Transcription fixture matching the LyricsTranscriptionSchema shape. Lines
// are 10 seconds apart starting at (n-1)*10 seconds.
export function linesBatch(from: number, to: number) {
  const lines = [];
  for (let n = from; n <= to; n++) {
    const start = (n - 1) * 10;
    lines.push({
      line_start: srt(start),
      line_end: srt(start + 3),
      line_text: `Line ${n}`,
      words: [
        { word: "Line", start: srt(start), end: srt(start + 1) },
        { word: String(n), start: srt(start + 2), end: srt(start + 3) },
      ],
    });
  }
  return lines;
}

export function srt(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  const ms = Math.round((seconds % 1) * 1000);
  const pad = (v: number, len = 2) => String(v).padStart(len, "0");
  return `${pad(h)}:${pad(m)}:${pad(s)},${pad(ms, 3)}`;
}

// The neutral phrases fixture downstream steps start from: two phrases, two
// words each.
export function phrasesFixture() {
  return [
    {
      id: "phrase_1",
      text_l1: "Bonjour le monde",
      timestamp: "00:05.00",
      timestamp_end: "00:08.00",
      words: [
        { text: "Bonjour", timestamp: "00:05.00", timestamp_end: "00:06.00" },
        { text: "monde", timestamp: "00:06.50", timestamp_end: "00:08.00" },
      ],
    },
    {
      id: "phrase_2",
      text_l1: "Salut encore",
      timestamp: "00:10.00",
      timestamp_end: "00:12.00",
      words: [
        { text: "Salut", timestamp: "00:10.00", timestamp_end: "00:11.00" },
        { text: "encore", timestamp: "00:11.20", timestamp_end: "00:12.00" },
      ],
    },
  ];
}
