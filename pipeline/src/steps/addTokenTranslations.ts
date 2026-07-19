// Port of CreateSong::AddTokenTranslations: translate each word of every
// phrase into the target language, batched into chunks of whole phrases and
// run with limited concurrency. Results are written per phrase into
// translations.<iso>.phrases.<i>.words as each chunk completes, so an aborted
// run resumes with only the phrases that are still missing — and never
// collides with the sentence-translation branch running in parallel.

import { generateText } from "ai";
import type { PatchOp, Phrase } from "../types.ts";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { addTokenTranslationsPrompt } from "../prompts/addTokenTranslations.ts";
import { message, withRetries } from "../retry.ts";

// Soft cap on words per LLM call. Chunks are packed by whole phrase, so a
// chunk may come in under this and a single over-long phrase may exceed it.
export const WORDS_PER_CHUNK = 200;

const MAX_CONCURRENCY = 4;
const MAX_RETRIES = 2;

interface WordEntry {
  phraseIndex: number;
  wordIndex: number;
  line: string;
}

export async function addTokenTranslations(ctx: PipelineContext): Promise<void> {
  const language = ctx.translationLanguage;
  if (!language) return;

  const phrases = ctx.store.data.phrases ?? [];
  const iso = language.iso_name;

  // One group per phrase still missing its token translations (resume skips
  // phrases whose payload words are already fully populated).
  const phraseGroups: WordEntry[][] = phrases
    .map((phrase, phraseIndex) =>
      (phrase.words ?? []).map((_, wordIndex) => ({
        phraseIndex,
        wordIndex,
        line: buildWordLine(phrase, wordIndex),
      }))
    )
    .filter((group, phraseIndex) =>
      group.length > 0 && !ctx.store.tokenTranslationsDoneFor(iso, phraseIndex)
    );

  if (phraseGroups.length === 0) return;

  const instructions = addTokenTranslationsPrompt(ctx.clipLanguage, language.english_name);
  const chunks = buildChunks(phraseGroups);

  const results = await mapWithConcurrency(chunks, MAX_CONCURRENCY, async (chunk) => {
    const translations = await translateChunk(ctx, instructions, chunk);

    // Persist this chunk immediately: group by phrase and write each phrase's
    // complete words array (chunks never split a phrase).
    const byPhrase = new Map<number, (string | null)[]>();
    chunk.forEach((entry, i) => {
      if (!byPhrase.has(entry.phraseIndex)) {
        const wordCount = phrases[entry.phraseIndex].words.length;
        byPhrase.set(entry.phraseIndex, new Array(wordCount).fill(null));
      }
      byPhrase.get(entry.phraseIndex)![entry.wordIndex] = translations[i];
    });

    const ops: PatchOp[] = [...byPhrase.entries()].map(([phraseIndex, words]) => ({
      op: "set",
      path: `translations.${iso}.phrases.${phraseIndex}.words`,
      value: words,
    }));
    await ctx.store.patch(ops);
  });

  const failures = results.filter((r) => r.status === "rejected");
  if (failures.length > 0) {
    throw (failures[0] as PromiseRejectedResult).reason;
  }
  await clearErrors(ctx, "add_token_translations");
}

async function translateChunk(
  ctx: PipelineContext,
  instructions: string,
  chunk: WordEntry[],
): Promise<string[]> {
  const lines = chunk.map((e) => e.line);
  let lastResponse: string | null = null;
  let attempts = 0;

  try {
    return await withRetries(
      async () => {
        const { text } = await generateText({
          model: ctx.models.tokenTranslations,
          system: instructions,
          prompt: lines.join("\n"),
        });
        lastResponse = text;
        return parseChunkTranslations(text.trim(), chunk.length);
      },
      {
        maxRetries: MAX_RETRIES,
        label: "AddTokenTranslations",
        baseDelayMs: ctx.baseDelayMs,
        onFailedAttempt: (_e, attempt) => (attempts = attempt),
      },
    );
  } catch (error) {
    // Record the failing chunk's input and the raw LLM response so a failed
    // course can be debugged after the fact (data.errors, same shape as the
    // Ruby pipeline wrote).
    await recordError(ctx, "add_token_translations", error, {
      attempts,
      input_lines: lines,
      agent_response: lastResponse,
    });
    throw new Error(`chunk of ${chunk.length} words failed: ${message(error)}`, { cause: error });
  }
}

// Greedily pack whole phrases into chunks of at most WORDS_PER_CHUNK words. A
// chunk must never end mid-phrase: every input line carries its full phrase as
// context, and a phrase cut across two chunks lets the model translate words
// it wasn't asked about, overshooting the expected line count. A phrase longer
// than the cap gets a chunk of its own.
export function buildChunks(phraseGroups: WordEntry[][]): WordEntry[][] {
  const chunks: WordEntry[][] = [];
  for (const group of phraseGroups) {
    const last = chunks.at(-1);
    if (last && last.length + group.length <= WORDS_PER_CHUNK) {
      last.push(...group);
    } else {
      chunks.push([...group]);
    }
  }
  return chunks;
}

// Build the input line for one word: the word, its phrase as context with the
// target word marked, and a trailing "|" for the model to complete.
//   apateu (Turn this *apateu* into a club) |
export function buildWordLine(phrase: Phrase, wordIndex: number): string {
  const words = phrase.words ?? [];
  const target = words[wordIndex].text;

  const context = words
    .map((w, i) => (i === wordIndex ? `*${w.text}*` : w.text))
    .join(" ");

  return `${target} (${context}) |`;
}

// Expects one "<word> (<context>) | <translation>" line per input line, in
// order. Ignores any lines that don't contain "|", then validates the count.
export function parseChunkTranslations(content: string, expectedCount: number): string[] {
  const translations = content
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l !== "" && l.includes("|"))
    .map((l) => l.slice(l.indexOf("|") + 1).trim());

  if (translations.length !== expectedCount) {
    throw new Error(
      `Word translation count mismatch: got ${translations.length}, expected ${expectedCount}`,
    );
  }
  return translations;
}

// Run `fn` over every item with at most `limit` in flight; resolves with one
// settled result per item (successes persist even when siblings fail).
async function mapWithConcurrency<T, R>(
  items: T[],
  limit: number,
  fn: (item: T) => Promise<R>,
): Promise<PromiseSettledResult<R>[]> {
  const results: PromiseSettledResult<R>[] = new Array(items.length);
  let next = 0;

  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const index = next++;
      try {
        results[index] = { status: "fulfilled", value: await fn(items[index]) };
      } catch (reason) {
        results[index] = { status: "rejected", reason };
      }
    }
  });

  await Promise.all(workers);
  return results;
}
