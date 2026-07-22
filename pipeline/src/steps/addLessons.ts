// Partition the complete aligned transcript into semantic comprehension lines
// and group those lines into lessons in one LLM call. The model returns only
// word-index ranges; all displayed text and timestamps are rebuilt from the
// original ElevenLabs words, so the model cannot rewrite or omit transcript.

import { generateObject } from "ai";
import { z } from "zod";
import type { Phrase, Word } from "../types.ts";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { addLessonsPrompt } from "../prompts/addLessons.ts";
import { withRetries } from "../retry.ts";

const MAX_RETRIES = 5;
const MAX_WORDS_PER_LINE = 20;

interface LineRange {
  start_word: number;
  end_word: number;
}

interface LessonPlan {
  title: string;
  lines: LineRange[];
}

const lessonOutputSchema = z.object({
  lessons: z.array(z.object({
    title: z.string(),
    lines: z.array(z.string()),
  })),
});

type LessonOutput = z.infer<typeof lessonOutputSchema>;

export async function addLessons(ctx: PipelineContext): Promise<void> {
  const words = (ctx.store.data.phrases ?? []).flatMap((phrase) => phrase.words);
  if (words.length === 0) throw new Error("No aligned transcript words to segment");
  const userContent = words.map((word) => word.text).join(" ");

  let lastResponse: string | null = null;
  let validationFeedback: string | null = null;
  let attempts = 0;

  try {
    const lessons = await withRetries(
      async () => {
        let result;
        try {
          result = await generateObject({
            model: ctx.models.addLessons,
            schema: lessonOutputSchema,
            system: addLessonsPrompt(ctx.clipLanguage, translationName(ctx)),
            prompt: validationFeedback
              ? `${userContent}\n\nYour previous partition was rejected: ${validationFeedback}\nReturn a corrected complete partition.`
              : userContent,
            temperature: 0.2,
          });
        } catch (error) {
          if (error && typeof error === "object" && "text" in error) {
            lastResponse = String(error.text);
          }
          throw error;
        }
        lastResponse = JSON.stringify(result.object);
        try {
          return parseAndValidateLessonPlan(result.object, words);
        } catch (error) {
          validationFeedback = error instanceof Error ? error.message : String(error);
          throw error;
        }
      },
      {
        maxRetries: MAX_RETRIES,
        label: "AddLessons",
        baseDelayMs: ctx.baseDelayMs,
        onFailedAttempt: (_e, attempt) => (attempts = attempt),
      },
    );

    const materialized = materializePlan(lessons, words);
    await ctx.store.patch([
      { op: "set", path: "lyric_lines", value: materialized.phrases.map((p) => p.text_l1) },
      { op: "set", path: "phrases", value: materialized.phrases },
      { op: "set", path: "lesson_outline", value: materialized.outline },
      { op: "set", path: "lessons", value: materialized.timestamped },
    ]);
    await clearErrors(ctx, "add_lessons");
  } catch (error) {
    await recordError(ctx, "add_lessons", error, {
      attempts: attempts || undefined,
      agent_response: lastResponse,
    });
    throw error;
  }
}

// Compatibility for resumed records whose older lesson step saved only an
// untimestamped outline. New runs materialize both forms atomically above.
export async function materializeLessons(ctx: PipelineContext): Promise<void> {
  const outline = ctx.store.data.lesson_outline;
  const phrases = ctx.store.data.phrases ?? [];
  if (!outline || phrases.length === 0 || ctx.store.data.lessons) return;

  const timestampedLines = phrases.map((phrase) => `${phrase.timestamp} ${phrase.text_l1}`).join(
    "\n",
  );
  await ctx.store.set("lessons", matchLessonDataToPrompt(timestampedLines, outline));
}

export function parseAndValidateLessonPlan(
  content: LessonOutput,
  words: Word[],
): LessonPlan[] {
  const lessons: LessonPlan[] = [];
  let cursor = 0;
  for (const [lessonIndex, lesson] of content.lessons.entries()) {
    const title = lesson.title.trim();
    if (!title) throw new Error("Lesson response contains an empty title");
    const plan: LessonPlan = { title, lines: [] };

    for (const line of lesson.lines) {
      const returnedWords = line.trim().split(/\s+/u);
      if (returnedWords.length > MAX_WORDS_PER_LINE) {
        throw new Error(`Lesson ${lessonIndex + 1} line exceeds ${MAX_WORDS_PER_LINE} words`);
      }
      const expectedWords = words.slice(cursor, cursor + returnedWords.length).map((word) =>
        word.text
      );
      const mismatch = returnedWords.findIndex((word, index) => word !== expectedWords[index]);
      if (mismatch >= 0 || line.trim() === "") {
        throw new Error(
          `Lesson transcript changed at word ${cursor + Math.max(0, mismatch)}: expected "${
            expectedWords[Math.max(0, mismatch)] ?? "end of transcript"
          }", got "${returnedWords[Math.max(0, mismatch)] ?? "end of line"}"`,
        );
      }
      plan.lines.push({
        start_word: cursor,
        end_word: cursor + returnedWords.length - 1,
      });
      cursor += returnedWords.length;
    }
    lessons.push(plan);
  }

  if (lessons.length === 0) throw new Error("Lesson response has no lessons");
  const emptyLesson = lessons.findIndex((lesson) => lesson.lines.length === 0);
  if (emptyLesson >= 0) throw new Error(`Lesson ${emptyLesson + 1} has no lines`);
  if (cursor !== words.length) {
    throw new Error(`Lesson plan covered ${cursor} of ${words.length} words`);
  }
  return lessons;
}

function materializePlan(lessons: LessonPlan[], words: Word[]) {
  const phrases: Phrase[] = [];
  const outline: string[] = [];
  const timestamped: string[] = [];

  for (const lesson of lessons) {
    outline.push(`# ${lesson.title}`);
    timestamped.push(`# ${lesson.title}`);
    for (const range of lesson.lines) {
      const lineWords = words.slice(range.start_word, range.end_word + 1);
      const text = lineWords.map((word) => word.text).join(" ").trim();
      const normalizedWords = withLineIndices(lineWords, text);
      phrases.push({
        id: `phrase_${phrases.length + 1}`,
        text_l1: text,
        timestamp: normalizedWords[0].timestamp,
        timestamp_end: normalizedWords.at(-1)!.timestamp_end,
        words: normalizedWords,
      });
      outline.push(text);
      timestamped.push(`${normalizedWords[0].timestamp} ${text}`);
    }
    outline.push("");
    timestamped.push("");
  }

  return {
    phrases,
    outline: outline.join("\n").trim(),
    timestamped: timestamped.join("\n").trim(),
  };
}

function withLineIndices(words: Word[], text: string): Word[] {
  let cursor = 0;
  return words.map((word) => {
    // PhraseToken character spans use inclusive end indexes and exclude
    // surrounding punctuation. Match WordTimingParser#locateWord exactly;
    // using an exclusive end here consumes the following space and makes a
    // final punctuated token extend beyond the phrase boundary.
    const needle = word.text.replace(/^[\p{P}\p{S}]+|[\p{P}\p{S}]+$/gu, "");
    if (!needle) return { ...word, l1_start_index: undefined, l1_end_index: undefined };
    const start = text.indexOf(needle, cursor);
    if (start < 0) {
      throw new Error(`Could not locate aligned word in reconstructed line: ${word.text}`);
    }
    const end = start + needle.length - 1;
    cursor = end + 1;
    return { ...word, l1_start_index: start, l1_end_index: end };
  });
}

function translationName(ctx: PipelineContext): string {
  return ctx.translationLanguage?.english_name ?? "English";
}

// Legacy outline materializer retained for resumable pre-change records.
export function matchLessonDataToPrompt(userContent: string, llmResponse: string): string {
  const responseLines = llmResponse.split("\n").filter((line) => line.trim() !== "");
  const blocks: Array<{ title: string; count: number }> = [];
  for (const line of responseLines) {
    if (line.startsWith("#") || blocks.length === 0) blocks.push({ title: line, count: 0 });
    else blocks.at(-1)!.count += 1;
  }

  const clipPhrases = userContent.split("\n").filter((line) => line.trim() !== "");
  const result: string[] = [];
  let cursor = 0;
  for (const { title, count } of blocks) {
    result.push(title, ...clipPhrases.slice(cursor, cursor + count), "\n");
    cursor += count;
  }
  return result.join("\n").replace(/\n{3,}/g, "\n\n").trim();
}
