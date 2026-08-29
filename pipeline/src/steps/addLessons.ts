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
import { capitalizeSentence, countLearnerTokens } from "../learnerTokens.ts";

// One initial call plus one retry.
const MAX_RETRIES = 1;
const MAX_WORDS_PER_LINE = 20;

interface LineRange {
  start_word: number;
  end_word: number;
}

interface SegmentationWord extends Word {
  sourceFragment?: string;
  hasSourceTiming?: boolean;
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
  const sourcePhrases = ctx.store.data.phrases ?? [];
  const hasWordTimings = sourcePhrases.some((phrase) =>
    phrase.words.some((word) => word.timestamp && word.timestamp_end)
  );
  // Gemini's alignment fallback timestamps lines, not words. Carry the source
  // line range only in memory so newly segmented phrases retain usable bounds;
  // materialization removes those synthetic values from the persisted words.
  const alignedWords = sourcePhrases.flatMap((phrase, phraseIndex) =>
    phrase.words.map((word, wordIndex) => {
      const nextStart = phrase.words[wordIndex + 1]?.l1_start_index;
      const start = word.l1_start_index;
      const sourceFragment = !hasWordTimings && start !== undefined
        ? phrase.text_l1.slice(start, nextStart) +
          (wordIndex === phrase.words.length - 1 && phraseIndex < sourcePhrases.length - 1
            ? " "
            : "")
        : undefined;
      return {
        ...word,
        hasSourceTiming: Boolean(word.timestamp && word.timestamp_end),
        timestamp: word.timestamp || phrase.timestamp,
        timestamp_end: word.timestamp_end || phrase.timestamp_end,
        sourceFragment,
      };
    })
  );
  const words = alignedWords;
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
          return parseAndValidateLessonPlan(result.object, words, ctx.clipLanguage);
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

    const materialized = materializePlan(lessons, words, hasWordTimings);
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
  clipLanguage = "",
): LessonPlan[] {
  const lessons: LessonPlan[] = [];
  let cursor = 0;
  for (const lesson of content.lessons) {
    const title = lesson.title.trim();
    if (!title) throw new Error("Lesson response contains an empty title");
    const plan: LessonPlan = { title, lines: [] };

    for (const line of lesson.lines) {
      const returnedWordCount = countLearnerTokens(line, clipLanguage);
      if (line.trim() === "") throw new Error("Lesson response contains an empty line");

      // The model owns only the boundaries. If it changes a word while copying
      // a line, retain the boundary and rebuild the text from aligned words.
      plan.lines.push(
        ...splitLineRange(
          cursor,
          words.slice(cursor, cursor + returnedWordCount).map((word) => word.text),
        ),
      );
      cursor += returnedWordCount;
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

function splitLineRange(startWord: number, words: string[]): LineRange[] {
  if (words.length <= MAX_WORDS_PER_LINE) {
    return [{ start_word: startWord, end_word: startWord + words.length - 1 }];
  }

  const splitAt = preferredSplit(words);
  return [
    ...splitLineRange(startWord, words.slice(0, splitAt)),
    ...splitLineRange(startWord + splitAt, words.slice(splitAt)),
  ];
}

function preferredSplit(words: string[]): number {
  const middle = words.length / 2;
  const periodBoundaries = punctuationBoundaries(words, /\.[\p{Pe}\p{Pf}"']*$/u);
  const commaBoundaries = punctuationBoundaries(words, /[,،][\p{Pe}\p{Pf}"']*$/u);
  const candidates = periodBoundaries.length > 0 ? periodBoundaries : commaBoundaries;

  if (candidates.length === 0) return Math.round(middle);
  return candidates.reduce((closest, candidate) =>
    Math.abs(candidate - middle) < Math.abs(closest - middle) ? candidate : closest
  );
}

function punctuationBoundaries(words: string[], pattern: RegExp): number[] {
  return words
    .slice(0, -1)
    .flatMap((word, index) => pattern.test(word) ? [index + 1] : []);
}

function materializePlan(
  lessons: LessonPlan[],
  words: SegmentationWord[],
  retainWordTimings: boolean,
) {
  const phrases: Phrase[] = [];
  const outline: string[] = [];
  const timestamped: string[] = [];

  for (const lesson of lessons) {
    outline.push(`# ${lesson.title}`);
    timestamped.push(`# ${lesson.title}`);
    for (const range of lesson.lines) {
      const lineWords = words.slice(range.start_word, range.end_word + 1).map((word) => ({
        ...word,
      }));
      lineWords[0].text = capitalizeSentence(lineWords[0].text);
      if (lineWords[0].sourceFragment !== undefined) {
        lineWords[0].sourceFragment = capitalizeSentence(lineWords[0].sourceFragment!);
      }
      const text = lineWords.some((word) => word.sourceFragment !== undefined)
        ? lineWords.map((word) => word.sourceFragment ?? word.text).join("").trim()
        : lineWords.map((word) => word.text).join(" ").trim();
      const lineStart = lineWords[0].timestamp!;
      const lineEnd = lineWords.at(-1)!.timestamp_end!;
      const normalizedWords = withLineIndices(lineWords, text, retainWordTimings);
      phrases.push({
        id: `phrase_${phrases.length + 1}`,
        text_l1: text,
        timestamp: lineStart,
        timestamp_end: lineEnd,
        words: normalizedWords,
      });
      outline.push(text);
      timestamped.push(`${lineStart} ${text}`);
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

function withLineIndices(
  words: SegmentationWord[],
  text: string,
  retainWordTimings: boolean,
): Word[] {
  let cursor = 0;
  return words.map((word) => {
    // PhraseToken character spans use inclusive end indexes and exclude
    // surrounding punctuation. Match WordTimingParser#locateWord exactly;
    // using an exclusive end here consumes the following space and makes a
    // final punctuated token extend beyond the phrase boundary.
    const needle = word.text.replace(/^[\p{P}\p{S}]+|[\p{P}\p{S}]+$/gu, "");
    if (!needle) {
      const {
        sourceFragment: _sourceFragment,
        hasSourceTiming: _hasSourceTiming,
        ...persistedWord
      } = word;
      const normalized = {
        ...persistedWord,
        l1_start_index: undefined,
        l1_end_index: undefined,
      };
      if (retainWordTimings && word.hasSourceTiming) return normalized;
      const { timestamp: _timestamp, timestamp_end: _timestampEnd, ...untimed } = normalized;
      return untimed;
    }
    const start = text.indexOf(needle, cursor);
    if (start < 0) {
      throw new Error(`Could not locate aligned word in reconstructed line: ${word.text}`);
    }
    const end = start + needle.length - 1;
    cursor = end + 1;
    const {
      sourceFragment: _sourceFragment,
      hasSourceTiming: _hasSourceTiming,
      ...persistedWord
    } = word;
    const normalized = { ...persistedWord, l1_start_index: start, l1_end_index: end };
    if (retainWordTimings && word.hasSourceTiming) return normalized;
    const { timestamp: _timestamp, timestamp_end: _timestampEnd, ...untimed } = normalized;
    return untimed;
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
