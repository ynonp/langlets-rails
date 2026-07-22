// Replaces the Ruby pipeline's DataFormat.pack_translation. Because the Deno
// steps write straight into translations.<iso> (instead of inline text_l2 /
// word translations that get moved later), "packing" reduces to two small
// jobs: creating the language payload skeleton before the fan-out, and
// stamping metadata + the clip-language lessons once every branch is done.

import { DATA_FORMAT_VERSION, type PatchOp, type TranslationPayload } from "../types.ts";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";

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

export async function materializeTranslationLines(ctx: PipelineContext): Promise<void> {
  const language = ctx.translationLanguage;
  if (!language) return;

  const lines = ctx.store.data.translation_lines?.[language.iso_name];
  const payload = ctx.store.translationPayload(language.iso_name);
  const sourceLines = ctx.store.data.lyric_lines ?? [];
  const phrases = ctx.store.data.phrases ?? [];
  if (!lines || !payload) return;

  try {
    let sourceCursor = 0;
    const alignedTranslations = phrases.map((phrase, phraseIndex) => {
      // Older/resumed blobs may have phrases and an intermediate but no saved
      // lyric_lines. Equal-sized arrays are unambiguous in that legacy case.
      if (sourceLines.length === 0 && lines.length === phrases.length) return lines[phraseIndex];

      const target = comparableLine(phrase.text_l1);
      const relativeIndex = sourceLines.slice(sourceCursor).findIndex((line) =>
        comparableLine(line) === target
      );
      const sourceIndex = relativeIndex < 0 ? -1 : sourceCursor + relativeIndex;
      if (sourceIndex < 0 || lines[sourceIndex] == null) {
        throw new Error(
          `Could not match aligned phrase to translated lyric line: ${phrase.text_l1}`,
        );
      }
      sourceCursor = sourceIndex + 1;
      return lines[sourceIndex];
    });

    const ops: PatchOp[] = alignedTranslations.map((text, index) => ({
      op: "set",
      path: `translations.${language.iso_name}.phrases.${index}.text`,
      value: text,
    }));
    await ctx.store.patch(ops);
    await clearErrors(ctx, "translate");
  } catch (error) {
    await recordError(ctx, "translate", error);
    throw error;
  }
}

function comparableLine(text: string): string {
  return text.replaceAll("[", "(").replaceAll("]", ")").trim();
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
