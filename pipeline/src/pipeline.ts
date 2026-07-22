// The workflow. Replaces CreateSongProgress#create_data's sequential run with
// a fan-out after the transcription steps:
//
//   extract_lyrics                          (Supadata native; Gemini fallback for YouTube)
//        │
//   force_alignment                         (ElevenLabs: word timings)
//        │
//   add_lessons                              (semantic lines + lesson hierarchy)
//        │
//        ├── add_token_translations
//        ├── rate_lessons
//        └── translate
//        │                                  (all three run concurrently)
//   materialize lessons + translations      (join with aligned phrases)
//        │
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
import { addLessons, materializeLessons } from "./steps/addLessons.ts";
import { rateLessons } from "./steps/rateLessons.ts";
import { translate } from "./steps/translate.ts";
import { addTokenTranslations } from "./steps/addTokenTranslations.ts";
import { addSimilarSound } from "./steps/addSimilarSound.ts";
import {
  finalizeTranslation,
  initTranslationPayload,
  materializeTranslationLines,
} from "./steps/finalizeTranslation.ts";
import type { Fuzzyword } from "./fuzzyword.ts";

export interface RunOptions {
  models: ModelRegistry;
  sink: ProgressSink;
  baseDelayMs?: number;
  // Test injection points for the similar-sound step.
  fuzzywordFor?: (code: string) => Promise<Fuzzyword | null>;
  random?: () => number;
  // Test injection point for Supadata transcription.
  transcribeVideo?: PipelineContext["transcribeVideo"];
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
    transcribeVideo: options.transcribeVideo,
    prepareAudio: options.prepareAudio,
    alignLyrics: options.alignLyrics,
  };
  console.log(`Pipeline start with payload: ${JSON.stringify(payload)}`);
  const failed: Record<string, string> = {};

  // Prefer existing provider captions. YouTube videos without usable native
  // captions fall back to Gemini. ElevenLabs then aligns the resulting text.
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

  // Semantic line boundaries are part of the neutral course skeleton. Nothing
  // may translate or index phrases until the lesson model has partitioned the
  // aligned word stream and we have validated complete, contiguous coverage.
  if (!store.lessonOutlineDone() && !store.lessonsDone()) {
    try {
      await addLessons(ctx);
    } catch (error) {
      failed.lessons = message(error);
      return result(store, failed);
    }
  }

  const preparation: Record<string, () => Promise<void>> = {
    lessons: async () => {
      if (!store.lessonsRated()) await rateLessons(ctx);
    },
    translate: async () => {
      const iso = ctx.translationLanguage?.iso_name;
      if (iso && !store.translationLinesDone(iso) && !store.translateDone(iso)) {
        await translate(ctx);
      }
    },
    token_translations: async () => {
      const iso = ctx.translationLanguage?.iso_name;
      if (!iso) return;
      await initTranslationPayload(ctx);
      if (!store.tokenTranslationsDone(iso)) await addTokenTranslations(ctx);
    },
  };
  const preparationLabels = Object.keys(preparation);
  const preparationSettled = await Promise.allSettled(
    preparationLabels.map((label) => preparation[label]()),
  );
  preparationSettled.forEach((r, i) => {
    if (r.status === "rejected") failed[preparationLabels[i]] = message(r.reason);
  });

  if (!failed.lessons && !store.lessonsDone()) {
    try {
      await materializeLessons(ctx);
    } catch (error) {
      failed.lessons = message(error);
    }
  }

  const iso = ctx.translationLanguage?.iso_name ?? null;
  if (iso) {
    await initTranslationPayload(ctx);
    if (!failed.translate && !store.translateDone(iso)) {
      try {
        await materializeTranslationLines(ctx);
      } catch (error) {
        failed.translate = message(error);
      }
    }
  }

  // Fan out. Each branch settles independently: a failure in one records its
  // error (steps append to data.errors themselves) without discarding the
  // others' completed — and persisted — work.
  const branches: Record<string, () => Promise<void>> = {
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
