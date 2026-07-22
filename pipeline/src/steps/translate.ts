// Translate the extracted lyric lines before force alignment finishes. The
// result is persisted at translation_lines.<iso>; after alignment creates the
// phrase payload, materializeTranslationLines copies it into the stable v2
// translations.<iso>.phrases shape.

import { generateText } from "ai";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { translatePrompt } from "../prompts/translate.ts";
import { withRetries } from "../retry.ts";

const MAX_RETRIES = 0;

export async function translate(ctx: PipelineContext): Promise<void> {
  const language = ctx.translationLanguage;
  if (!language) return;

  const originalLyrics = ctx.store.data.lyric_lines ??
    (ctx.store.data.phrases ?? []).map((phrase) => phrase.text_l1);
  const userContent = originalLyrics.join("\n");

  let lastResponse: string | null = null;
  let attempts = 0;

  try {
    const translationLines = await withRetries(
      async () => {
        const { text } = await generateText({
          model: ctx.models.translate,
          system: translatePrompt(ctx.clipLanguage, language.english_name, originalLyrics.length),
          prompt: userContent,
          temperature: 0.2,
        });
        lastResponse = text;

        const lines = text
          .split("\n")
          .map((l) => l.replace(/\s+$/, ""))
          .filter((l) => l.trim() !== "");
        if (lines.length !== originalLyrics.length) {
          throw new Error(
            `Bad translation, line count doesnt match ${lines.length} != ${originalLyrics.length}`,
          );
        }
        return lines;
      },
      {
        maxRetries: MAX_RETRIES,
        label: "Translate",
        baseDelayMs: ctx.baseDelayMs,
        onFailedAttempt: (_e, attempt) => (attempts = attempt),
      },
    );

    await ctx.store.set(
      `translation_lines.${language.iso_name}`,
      translationLines.map((text) => text.replaceAll("[", "(").replaceAll("]", ")")),
    );
    await clearErrors(ctx, "translate");
  } catch (error) {
    await recordError(ctx, "translate", error, {
      attempts: attempts || undefined,
      agent_response: lastResponse,
    });
    throw error;
  }
}
