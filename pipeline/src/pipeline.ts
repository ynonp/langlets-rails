// The workflow. Replaces CreateSongProgress#create_data's sequential run with
// a fan-out after the transcription steps:
//
//   extract_lyrics                          (Gemini: the lyrics text)
//        │
//   force_alignment                         (word timings, Gemini as backup)
//        │
//        ├── add_lessons ──► rate_lessons   (lessons branch)
//        ├── translate                      (sentence translations)
//        ├── add_token_translations         (word translations, 4-way chunked)
//        └── add_similar_sound              (dictionary lookup, no LLM)
//        │
//   finalize_translation                    (payload metadata + lessons)
//
// The branches touch disjoint keys of CreateSongProgress.data, so they can
// run concurrently; each persists through the callback as it goes. Every step
// is guarded by the same data predicates Rails uses, so running the pipeline
// again with the saved data resumes paused work and retries only the failed
// branches.

import type { LanguageRef, ProgressData, ProgressSink, TriggerPayload } from "./types.ts";
import { ProgressStore } from "./progress.ts";
import type { ModelRegistry } from "./models.ts";
import type { PipelineContext } from "./context.ts";
import { dataSummary } from "./context.ts";
import { message } from "./retry.ts";
import { extractLyrics } from "./steps/extractLyrics.ts";
import { forceAlignment } from "./steps/forceAlignment.ts";
import { addLessons } from "./steps/addLessons.ts";
import { rateLessons } from "./steps/rateLessons.ts";
import { translate } from "./steps/translate.ts";
import { addTokenTranslations } from "./steps/addTokenTranslations.ts";
import { addSimilarSound } from "./steps/addSimilarSound.ts";
import { finalizeTranslation, initTranslationPayload } from "./steps/finalizeTranslation.ts";
import type { Fuzzyword } from "./fuzzyword.ts";

export interface RunOptions {
  models: ModelRegistry;
  sink: ProgressSink;
  baseDelayMs?: number;
  // Test injection points for the similar-sound step.
  fuzzywordFor?: (code: string) => Promise<Fuzzyword | null>;
  random?: () => number;
  // Test injection points for the force_alignment step's audio download and
  // the ElevenLabs forced-alignment call.
  prepareAudio?: PipelineContext["prepareAudio"];
  alignLyrics?: PipelineContext["alignLyrics"];
}

export interface RunResult {
  ok: boolean;
  // Branch label -> error message for every branch that failed this run.
  failed: Record<string, string>;
  data: ProgressData;
  summary: Record<string, unknown>;
}

export async function runPipeline(
  payload: TriggerPayload,
  options: RunOptions,
): Promise<RunResult> {
  const store = new ProgressStore(payload.data, options.sink);
  const ctx: PipelineContext = {
    store,
    models: options.models,
    youtubeurl: payload.youtubeurl,
    clipLanguage: payload.clip_language,
    clipLanguageIso: payload.clip_language_iso,
    translationLanguage: payload.translation_language,
    baseDelayMs: options.baseDelayMs ?? 1000,
    fuzzywordFor: options.fuzzywordFor,
    random: options.random,
    prepareAudio: options.prepareAudio,
    alignLyrics: options.alignLyrics,
  };
  console.log(`Pipeline start with payload: ${JSON.stringify(payload)}`);
  const failed: Record<string, string> = {};

  // Transcribe, then time. Each step runs when its own output is missing or
  // when a previous run started it but never finished it (the in-progress flag
  // is still set) — saved output alone can't tell "done" apart from
  // "interrupted" because the steps save as they go. Nothing downstream can
  // run without timed phrases, so a failure in either one reports and stops.
  if (!store.extractLyricsDone()) {
    try {
      await extractLyrics(ctx);
    } catch (error) {
      failed.extract_lyrics = message(error);
      return result(store, failed);
    }
  }

  if (!store.forceAlignmentDone()) {
    try {
      await forceAlignment(ctx);
    } catch (error) {
      failed.force_alignment = message(error);
      return result(store, failed);
    }
  }

  const iso = ctx.translationLanguage?.iso_name ?? null;
  if (iso) await initTranslationPayload(ctx);

  // Fan out. Each branch settles independently: a failure in one records its
  // error (steps append to data.errors themselves) without discarding the
  // others' completed — and persisted — work.
  const branches: Record<string, () => Promise<void>> = {
    lessons: async () => {
      if (!store.lessonsDone()) await addLessons(ctx);
      if (!store.lessonsRated()) await rateLessons(ctx);
    },
    translate: async () => {
      if (iso && !store.translateDone(iso)) await translate(ctx);
    },
    token_translations: async () => {
      if (iso && !store.tokenTranslationsDone(iso)) await addTokenTranslations(ctx);
    },
    similar_sounds: async () => {
      if (!store.similarSoundsDone()) await addSimilarSound(ctx);
    },
  };

  const labels = Object.keys(branches);
  const settled = await Promise.allSettled(labels.map((label) => branches[label]()));
  settled.forEach((r, i) => {
    if (r.status === "rejected") failed[labels[i]] = message(r.reason);
  });

  // Finalize even when the lessons branch failed: translations that finished
  // should be fully usable; a rerun fills in lessons later.
  if (iso && !failed.translate && !failed.token_translations) {
    try {
      await finalizeTranslation(ctx);
    } catch (error) {
      failed.finalize_translation = message(error);
    }
  }

  return result(store, failed);
}

function result(store: ProgressStore, failed: Record<string, string>): RunResult {
  return {
    ok: Object.keys(failed).length === 0,
    failed,
    data: store.data,
    summary: dataSummary(store.data),
  };
}

export function parseTriggerPayload(raw: unknown): TriggerPayload {
  const body = raw as Partial<TriggerPayload>;
  if (!body || typeof body !== "object") throw new Error("payload must be a JSON object");
  if (!body.youtubeurl) throw new Error("youtubeurl is required");
  if (!body.clip_language) throw new Error("clip_language is required");
  if (!body.callback_url) throw new Error("callback_url is required");

  const language = body.translation_language ?? null;
  if (language && !language.iso_name) {
    throw new Error("translation_language.iso_name is required when translation_language is set");
  }

  return {
    youtubeurl: body.youtubeurl,
    clip_language: body.clip_language,
    clip_language_iso: body.clip_language_iso ?? null,
    translation_language: language
      ? {
        id: language.id ?? null,
        iso_name: language.iso_name,
        english_name: language.english_name ?? language.iso_name,
      } satisfies LanguageRef
      : null,
    callback_url: body.callback_url,
    data: body.data ?? {},
  };
}
