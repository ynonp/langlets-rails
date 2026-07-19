// Port of CreateSong::RateLessons: score each lesson's pedagogical value 1-5
// so low-value lessons (chants, reprises) can be filtered out of the course.

import { generateText } from "ai";
import type { LessonRating } from "../types.ts";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { rateLessonsPrompt } from "../prompts/rateLessons.ts";
import { withRetries } from "../retry.ts";

const MAX_RETRIES = 5;

export async function rateLessons(ctx: PipelineContext): Promise<void> {
  const lessons = ctx.store.data.lessons;
  if (!lessons || lessons.trim() === "") return;

  let lastResponse: string | null = null;
  let attempts = 0;

  try {
    const ratings = await withRetries(
      async () => {
        const { text } = await generateText({
          model: ctx.models.rateLessons,
          system: rateLessonsPrompt(ctx.clipLanguage, translationName(ctx)),
          prompt: lessons,
          temperature: 0.2,
        });
        lastResponse = text;
        if (!text) throw new Error("LLM returned nil");

        const parsed = parseRatings(text);
        if (parsed.length === 0) throw new Error("No ratings parsed");
        return parsed;
      },
      {
        maxRetries: MAX_RETRIES,
        label: "RateLessons",
        baseDelayMs: ctx.baseDelayMs,
        onFailedAttempt: (_e, attempt) => (attempts = attempt),
      },
    );

    await ctx.store.set("lesson_ratings", ratings);
    await clearErrors(ctx, "rate_lessons");
  } catch (error) {
    await recordError(ctx, "rate_lessons", error, {
      attempts: attempts || undefined,
      agent_response: lastResponse,
    });
    throw error;
  }
}

function translationName(ctx: PipelineContext): string {
  return ctx.translationLanguage?.english_name ?? "English";
}

// The LLM is asked for a bare JSON array, but tolerate markdown fences and any
// surrounding prose by extracting the first [...] block.
export function parseRatings(content: string): LessonRating[] {
  const match = content.match(/\[[\s\S]*\]/);
  if (!match) return [];

  try {
    const parsed = JSON.parse(match[0]);
    if (!Array.isArray(parsed)) return [];

    return parsed.map((row) => ({
      index: row.index,
      title: String(row.title ?? "").trim(),
      score: Math.trunc(Number(row.score) || 0),
      reason: String(row.reason ?? "").trim(),
    }));
  } catch {
    return [];
  }
}
