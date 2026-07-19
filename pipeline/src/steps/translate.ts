// Port of CreateSong::Translate: translate every phrase line into the target
// language. Unlike the Ruby version (which wrote text_l2 inline on each phrase
// and relied on pack_translation to move it later), this writes straight into
// the language's payload at translations.<iso>.phrases.<i>.text — that keeps
// it from ever touching the same keys as the token-translation branch running
// in parallel.

import { generateText } from "ai";
import type { PatchOp } from "../types.ts";
import type { PipelineContext } from "../context.ts";
import { recordError } from "../context.ts";
import { translatePrompt } from "../prompts/translate.ts";
import { withRetries } from "../retry.ts";

const MAX_RETRIES = 0;

export async function translate(ctx: PipelineContext): Promise<void> {
  const language = ctx.translationLanguage;
  if (!language) return;

  const phrases = ctx.store.data.phrases ?? [];
  const originalLyrics = phrases.map((p) => p.text_l1);
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
        if (lines.length !== phrases.length) {
          throw new Error(
            `Bad translation, line count doesnt match ${lines.length} != ${phrases.length}`,
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

    const ops: PatchOp[] = translationLines.map((text, i) => ({
      op: "set",
      path: `translations.${language.iso_name}.phrases.${i}.text`,
      value: text.replaceAll("[", "(").replaceAll("]", ")"),
    }));
    await ctx.store.patch(ops);
  } catch (error) {
    await recordError(ctx, "translate", error, {
      attempts: attempts || undefined,
      agent_response: lastResponse,
    });
    throw error;
  }
}
