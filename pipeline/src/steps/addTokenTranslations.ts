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
const PARTS_OF_SPEECH = new Set([
  "noun",
  "proper_noun",
  "verb",
  "adjective",
  "adverb",
  "pronoun",
  "determiner",
  "preposition",
  "conjunction",
  "auxiliary",
  "particle",
  "interjection",
  "numeral",
  "punctuation",
  "other",
]);

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

  // Collapse identical phrases before batching, so repeats are deduplicated
  // across the entire song rather than only when they happen to share a
  // chunk. If a repeat was completed by an earlier run, reuse it immediately.
  const phraseIndexesBySignature = new Map<string, number[]>();
  phrases.forEach((phrase, phraseIndex) => {
    if (phrase.words.length === 0) return;
    const signature = JSON.stringify(phrase.words.map((word) => word.text));
    const indexes = phraseIndexesBySignature.get(signature) ?? [];
    indexes.push(phraseIndex);
    phraseIndexesBySignature.set(signature, indexes);
  });

  const duplicateIndexesByRepresentative = new Map<number, number[]>();
  const reuseOps: PatchOp[] = [];
  const phraseGroups: WordEntry[][] = [];

  for (const phraseIndexes of phraseIndexesBySignature.values()) {
    const completedIndex = phraseIndexes.find((index) =>
      ctx.store.tokenTranslationsDoneFor(iso, index)
    );
    if (completedIndex !== undefined) {
      const words = ctx.store.translationPayload(iso)!.phrases[completedIndex].words;
      for (const phraseIndex of phraseIndexes) {
        if (!ctx.store.tokenTranslationsDoneFor(iso, phraseIndex)) {
          reuseOps.push({
            op: "set",
            path: `translations.${iso}.phrases.${phraseIndex}.words`,
            value: [...words],
          });
        }
      }
      continue;
    }

    const representative = phraseIndexes[0];
    duplicateIndexesByRepresentative.set(representative, phraseIndexes);
    phraseGroups.push(phrases[representative].words.map((_, wordIndex) => ({
      phraseIndex: representative,
      wordIndex,
      line: buildWordLine(phrases[representative], wordIndex),
    })));
  }

  if (reuseOps.length > 0) await ctx.store.patch(reuseOps);

  if (phraseGroups.length === 0) return;

  const instructions = addTokenTranslationsPrompt(ctx.clipLanguage, language.english_name);
  const chunks = buildChunks(phraseGroups);

  const results = await mapWithConcurrency(chunks, MAX_CONCURRENCY, async (chunk) => {
    const translations = await translateChunk(ctx, instructions, chunk);

    // Persist this chunk immediately: group by representative phrase, then
    // fan its complete words array out to every identical phrase occurrence.
    const byPhrase = new Map<number, (string | null)[]>();
    chunk.forEach((entry, i) => {
      if (!byPhrase.has(entry.phraseIndex)) {
        const wordCount = phrases[entry.phraseIndex].words.length;
        byPhrase.set(entry.phraseIndex, new Array(wordCount).fill(null));
      }
      byPhrase.get(entry.phraseIndex)![entry.wordIndex] = translations[i];
    });

    const ops: PatchOp[] = [...byPhrase.entries()].flatMap(([representative, words]) =>
      duplicateIndexesByRepresentative.get(representative)!.map((phraseIndex) => ({
        op: "set" as const,
        path: `translations.${iso}.phrases.${phraseIndex}.words`,
        value: [...words],
      }))
    );
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
  translations.forEach((translation, index) => {
    const partOfSpeech = translation.match(/\[([a-z_]+)\]\s*$/i)?.[1].toLowerCase();
    if (!partOfSpeech || !PARTS_OF_SPEECH.has(partOfSpeech)) {
      throw new Error(`Missing or invalid part of speech on word translation ${index + 1}`);
    }
  });
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
