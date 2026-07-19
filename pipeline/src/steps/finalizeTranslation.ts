// Replaces the Ruby pipeline's DataFormat.pack_translation. Because the Deno
// steps write straight into translations.<iso> (instead of inline text_l2 /
// word translations that get moved later), "packing" reduces to two small
// jobs: creating the language payload skeleton before the fan-out, and
// stamping metadata + the clip-language lessons once every branch is done.

import { DATA_FORMAT_VERSION, type PatchOp, type TranslationPayload } from "../types.ts";
import type { PipelineContext } from "../context.ts";

// Ensure translations.<iso> exists with one slot per phrase before the
// parallel branches start writing into it. On resume an existing payload is
// kept as-is — its filled slots are exactly what lets the branches skip work.
export async function initTranslationPayload(ctx: PipelineContext): Promise<void> {
  const language = ctx.translationLanguage;
  if (!language) return;

  const existing = ctx.store.translationPayload(language.iso_name);
  const phrases = ctx.store.data.phrases ?? [];

  if (existing && existing.phrases?.length === phrases.length) return;

  const payload: TranslationPayload = {
    language_id: language.id,
    language_name: language.english_name,
    phrases: phrases.map((p, i) =>
      existing?.phrases?.[i] ?? { text: null, words: new Array(p.words.length).fill(null) }
    ),
    lessons: existing?.lessons ?? null,
  };

  const ops: PatchOp[] = [
    { op: "set", path: `translations.${language.iso_name}`, value: payload },
    // Stamp before any translation content lands: an interrupted run must not
    // leave a blob that shape-classifies as legacy on retry.
    { op: "set", path: "format_version", value: DATA_FORMAT_VERSION },
  ];
  await ctx.store.patch(ops);
}

// Copy the (clip-language) lessons into the payload — the payload snapshot of
// lessons is what CourseBuilder uses when adding this language to an existing
// course.
export async function finalizeTranslation(ctx: PipelineContext): Promise<void> {
  const language = ctx.translationLanguage;
  if (!language) return;

  const ops: PatchOp[] = [
    { op: "set", path: `translations.${language.iso_name}.language_id`, value: language.id },
    {
      op: "set",
      path: `translations.${language.iso_name}.language_name`,
      value: language.english_name,
    },
    {
      op: "set",
      path: `translations.${language.iso_name}.lessons`,
      value: ctx.store.data.lessons ?? null,
    },
  ];
  await ctx.store.patch(ops);
}
