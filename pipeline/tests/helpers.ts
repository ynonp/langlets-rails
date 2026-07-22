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
import type { TranscriptResult } from "../src/supadata.ts";
import type { Alignment } from "../src/alignment.ts";
import type { DownloadedAudio } from "../src/audio.ts";

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

// Network-free Supadata stand-in for step and orchestration tests.
export interface StubTranscriber {
  transcribe: NonNullable<PipelineContext["transcribeVideo"]>;
  calls: () => number;
  requests: Array<{ videoUrl: string; languageCode: string | null }>;
}

export function stubTranscribe(responses: Array<TranscriptResult | Error>): StubTranscriber {
  let count = 0;
  const requests: StubTranscriber["requests"] = [];

  return {
    transcribe: (videoUrl, languageCode) => {
      requests.push({ videoUrl, languageCode });
      if (count >= responses.length) throw new Error("stub transcriber exhausted");
      const next = responses[count++];
      if (next instanceof Error) return Promise.reject(next);
      return Promise.resolve(next);
    },
    calls: () => count,
    requests,
  };
}

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
  transcribeVideo?: PipelineContext["transcribeVideo"];
  prepareAudio?: PipelineContext["prepareAudio"];
  alignLyrics?: PipelineContext["alignLyrics"];
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
    transcribeVideo: options.transcribeVideo,
    prepareAudio: options.prepareAudio,
    alignLyrics: options.alignLyrics,
  };

  return { ctx, store, sink };
}

export const STUB_AUDIO_PATH = "/tmp/langlets-test-audio.m4a";

export function stubAudioWith(durationSeconds: number | null) {
  return (): Promise<DownloadedAudio> =>
    Promise.resolve({ path: STUB_AUDIO_PATH, durationSeconds });
}

export function alignment(words: Alignment["words"]): Alignment {
  return { words, loss: null };
}

export function alignedBatch(from: number, to: number): Alignment["words"] {
  return Array.from({ length: to - from + 1 }, (_, index) => index + from).flatMap((n) => {
    const start = (n - 1) * 10;
    return [
      { text: "Line", start, end: start + 1 },
      { text: String(n), start: start + 2, end: start + 3 },
    ];
  });
}

export function stubAlign(responses: Array<Alignment | Error>) {
  let count = 0;
  const requests: Array<{ audioPath: string; text: string }> = [];
  return {
    align: (audioPath: string, text: string) => {
      requests.push({ audioPath, text });
      const next = responses[count++];
      return next instanceof Error ? Promise.reject(next) : Promise.resolve(next);
    },
    calls: () => count,
    requests,
  };
}

// Timestamped Supadata fixture for lines "Line 1", "Line 2", ... .
export function lyricsText(from: number, to: number): string {
  const lines = [];
  for (let n = from; n <= to; n++) lines.push(`Line ${n}`);
  return lines.join("\n");
}

export function transcriptFixture(from: number, to: number): TranscriptResult {
  const content = [];
  for (let n = from; n <= to; n++) {
    content.push({
      text: `Line ${n}`,
      offset: (n - 1) * 10_000,
      duration: 3_000,
      lang: "fr",
    });
  }
  return { content, lang: "fr", availableLangs: ["fr"] };
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
