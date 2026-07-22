// Group the extracted lyric lines into short titled lessons. This deliberately
// runs before phrase timings exist, in parallel with force alignment. The LLM
// output is normalized back to our own lyric text and saved as lesson_outline;
// materializeLessons adds timestamps after the two branches join.

import { generateText } from "ai";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { addLessonsPrompt } from "../prompts/addLessons.ts";
import { withRetries } from "../retry.ts";

const MAX_RETRIES = 5;

export async function addLessons(ctx: PipelineContext): Promise<void> {
  const sourceLines = ctx.store.data.lyric_lines ??
    (ctx.store.data.phrases ?? []).map((phrase) => phrase.text_l1);
  const userContent = sourceLines.join("\n");

  let lastResponse: string | null = null;
  let attempts = 0;

  try {
    const outline = await withRetries(
      async () => {
        const { text } = await generateText({
          model: ctx.models.addLessons,
          system: addLessonsPrompt(ctx.clipLanguage, translationName(ctx)),
          prompt: userContent,
          temperature: 0.4,
        });
        lastResponse = text;
        if (!text) throw new Error("LLM returned nil");

        return matchLessonDataToPrompt(userContent, text);
      },
      {
        maxRetries: MAX_RETRIES,
        label: "AddLessons",
        baseDelayMs: ctx.baseDelayMs,
        onFailedAttempt: (_e, attempt) => (attempts = attempt),
      },
    );

    await ctx.store.set("lesson_outline", outline);
    await clearErrors(ctx, "add_lessons");
  } catch (error) {
    await recordError(ctx, "add_lessons", error, {
      attempts: attempts || undefined,
      agent_response: lastResponse,
    });
    throw error;
  }
}

export async function materializeLessons(ctx: PipelineContext): Promise<void> {
  const outline = ctx.store.data.lesson_outline;
  const phrases = ctx.store.data.phrases ?? [];
  if (!outline || phrases.length === 0) return;

  const timestampedLines = phrases.map((phrase) => `${phrase.timestamp} ${phrase.text_l1}`).join(
    "\n",
  );
  await ctx.store.set("lessons", matchLessonDataToPrompt(timestampedLines, outline));
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
