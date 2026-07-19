// Port of CreateSong::AddLessons: group the transcribed phrases into short
// titled lessons. The LLM returns titles + line groupings; we keep our own
// phrase text (matched by count per block) so the lesson body is always
// verbatim transcript lines, never the model's paraphrase.

import { generateText } from "ai";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { addLessonsPrompt } from "../prompts/addLessons.ts";
import { withRetries } from "../retry.ts";

const MAX_RETRIES = 5;

export async function addLessons(ctx: PipelineContext): Promise<void> {
  const phrases = ctx.store.data.phrases ?? [];
  const clipLines = phrases.map((p) => `${p.timestamp} ${p.text_l1}`).join("\n");
  const userContent = phrases.map((p) => p.text_l1).join("\n");

  let lastResponse: string | null = null;
  let attempts = 0;

  try {
    const lessons = await withRetries(
      async () => {
        const { text } = await generateText({
          model: ctx.models.addLessons,
          system: addLessonsPrompt(ctx.clipLanguage, translationName(ctx)),
          prompt: userContent,
          temperature: 0.4,
        });
        lastResponse = text;
        if (!text) throw new Error("LLM returned nil");

        return matchLessonDataToPrompt(clipLines, text);
      },
      {
        maxRetries: MAX_RETRIES,
        label: "AddLessons",
        baseDelayMs: ctx.baseDelayMs,
        onFailedAttempt: (_e, attempt) => (attempts = attempt),
      },
    );

    await ctx.store.set("lessons", lessons);
    await clearErrors(ctx, "add_lessons");
  } catch (error) {
    await recordError(ctx, "add_lessons", error, {
      attempts: attempts || undefined,
      agent_response: lastResponse,
    });
    throw error;
  }
}

function translationName(ctx: PipelineContext): string {
  return ctx.translationLanguage?.english_name ?? "English";
}

// Split the LLM response into blocks (a "# title" line plus its body lines),
// then rebuild each block from our own timestamped clip lines: the title comes
// from the model, the body lines come from the transcript, matched by count.
export function matchLessonDataToPrompt(userContent: string, llmResponse: string): string {
  const responseLines = llmResponse.split("\n").filter((l) => l.trim() !== "");

  const blocks: Array<{ title: string; count: number }> = [];
  for (const line of responseLines) {
    if (line.startsWith("#") || blocks.length === 0) {
      blocks.push({ title: line, count: 0 });
    } else {
      blocks[blocks.length - 1].count += 1;
    }
  }

  const clipPhrases = userContent.split("\n").filter((l) => l.trim() !== "");
  const result: string[] = [];
  let cursor = 0;
  for (const { title, count } of blocks) {
    result.push(title);
    result.push(...clipPhrases.slice(cursor, cursor + count));
    cursor += count;
    result.push("\n");
  }
  return result.join("\n").replace(/\n{3,}/g, "\n\n").trim();
}
