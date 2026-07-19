// Everything a step needs: the working data (store), the models, the request
// parameters, and error reporting that lands in data.errors — the same shape
// the Ruby pipeline writes today, so failed LLM responses stay inspectable.

import type { LanguageRef, PipelineError, ProgressData } from "./types.ts";
import type { ProgressStore } from "./progress.ts";
import type { ModelRegistry } from "./models.ts";
import type { Fuzzyword } from "./fuzzyword.ts";
import type { DownloadedAudio } from "./audio.ts";
import type { Alignment } from "./alignment.ts";
import { errorClass, message } from "./retry.ts";

export interface PipelineContext {
  store: ProgressStore;
  models: ModelRegistry;
  youtubeurl: string;
  clipLanguage: string;
  clipLanguageIso?: string | null;
  translationLanguage: LanguageRef | null;
  // Scales retry/backoff delays; tests set 0.
  baseDelayMs: number;
  // Injection points for the similar-sound step (tests swap in a tiny
  // dictionary and a fixed RNG).
  fuzzywordFor?: (code: string) => Promise<Fuzzyword | null>;
  random?: () => number;
  // Injection points for the transcription step (tests stub out the YouTube
  // audio download and the ElevenLabs forced-alignment call).
  prepareAudio?: (youtubeUrl: string) => Promise<DownloadedAudio>;
  alignLyrics?: (audioPath: string, text: string) => Promise<Alignment>;
}

export interface FailureDetails {
  attempts?: number;
  input_lines?: string[] | null;
  agent_response?: string | null;
}

// Append a failure entry to data.errors (persisted through the callback, so
// it survives even when the run aborts right after). Never let error
// bookkeeping mask the original failure.
export async function recordError(
  ctx: PipelineContext,
  step: string,
  error: unknown,
  details: FailureDetails = {},
): Promise<void> {
  const entry: PipelineError = {
    step,
    occurred_at: new Date().toISOString(),
    error_class: errorClass(error),
    error_message: message(error),
    input_lines: details.input_lines ?? null,
    agent_response: details.agent_response ?? null,
    ...(details.attempts !== undefined ? { attempts: details.attempts } : {}),
  };

  try {
    await ctx.store.append("errors", entry);
  } catch (persistError) {
    console.error(`Failed to persist ${step} failure: ${message(persistError)}`);
  }
}

// A retry that completes makes earlier failures for that same action stale.
// Use a dedicated patch op instead of replacing the whole errors array so a
// concurrent branch cannot have its newly appended failure overwritten.
export async function clearErrors(ctx: PipelineContext, step: string): Promise<void> {
  await ctx.store.clearErrors(step);
}

export function dataSummary(data: ProgressData): Record<string, unknown> {
  return {
    phrases: data.phrases?.length ?? 0,
    lessons: Boolean(data.lessons),
    lesson_ratings: data.lesson_ratings?.length ?? 0,
    translations: Object.keys(data.translations ?? {}),
    errors: data.errors?.length ?? 0,
  };
}
