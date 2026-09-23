// Port of CreateSong::RateLessons: score each lesson's pedagogical value 1-5
// so low-value lessons (chants, reprises) can be filtered out of the course.

import { generateText } from "ai";
import type { LessonRating } from "../types.ts";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordWarning } from "../context.ts";
import { rateLessonsPrompt } from "../prompts/rateLessons.ts";
import { formatErrorDiagnostics, withRetries } from "../retry.ts";

// One initial call plus three retries.
const MAX_RETRIES = 3;

export async function rateLessons(ctx: PipelineContext): Promise<void> {
  // Ratings depend only on the grouping and titles, not on word timings.
  const lessons = ctx.store.data.lesson_outline ?? ctx.store.data.lessons;
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
    const fallback = keepAllRatings(lessons);
    console.error(
      `RateLessons failed; retaining all ${fallback.length} lessons: ${
        formatErrorDiagnostics(error)
      }`,
    );

    // A previous failed run can leave a blocking rate_lessons error behind.
    // Clear it before marking the optional quality step complete.
    await clearErrors(ctx, "rate_lessons");
    await recordWarning(ctx, "rate_lessons", error, "retained_all_lessons", {
      attempts: attempts || undefined,
      agent_response: lastResponse,
    });
    await ctx.store.set("lesson_ratings", fallback);
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

function keepAllRatings(lessons: string): LessonRating[] {
  return lessons.split("\n").filter((line) => line.startsWith("# ")).map((line, index) => ({
    index: index + 1,
    title: line.slice(2).trim(),
    score: 5,
    reason: "Rating unavailable; lesson retained.",
  }));
}
