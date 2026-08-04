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
import { mapWithConcurrency } from "../concurrency.ts";

// Soft cap on input lines per LLM call. There is one line per learner token.
// Chunks are packed by whole phrase, so a chunk may come in under this and a
// single over-long phrase may exceed it.
export const LINES_PER_CHUNK = 200;

const MAX_CONCURRENCY = 4;
const MAX_RETRIES = 2;

// A response that repeats the source word instead of translating it satisfies
// every other check here — the line count matches and the part of speech is
// real — so a whole course can ship with its "translations" in the source
// language and nothing reports a failure. Measure it directly: above this
// share of echoed words the chunk is a bad response, not a hard phrase.
//
// Some echo is correct (proper names, cognates, loanwords, numerals), which is
// why the bar is a ratio rather than a single line, and why a chunk too small
// for the ratio to mean anything is never failed on it — a four-word TikTok
// clip of nothing but names is not a broken run.
export const MAX_ECHO_RATIO = 0.3;
export const MIN_ECHO_SAMPLE = 8;
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
  // The source word on its own, kept alongside the line the model sees so the
  // echo check can compare against it without re-parsing the line.
  text: string;
  line: string;
}

export async function addTokenTranslations(
  ctx: PipelineContext,
  promptBuilder = addTokenTranslationsPrompt,
): Promise<void> {
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
    phraseGroups.push(phrases[representative].words.map((word, wordIndex) => ({
      phraseIndex: representative,
      wordIndex,
      text: word.text,
      line: buildWordLine(phrases[representative], wordIndex),
    })));
  }

  if (reuseOps.length > 0) await ctx.store.patch(reuseOps);

  if (phraseGroups.length === 0) return;

  const instructions = promptBuilder(ctx.clipLanguage, language.english_name);
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
          temperature: 0,
          providerOptions: { ollama: { reasoningEffort: "none" } },
        });
        lastResponse = text;
        const translations = parseChunkTranslations(text.trim(), chunk.length);
        assertNotEchoed(chunk.map((e) => e.text), translations);
        return translations;
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

// The cap counts generated prompt lines, which are one-to-one with learner
// tokens. Whole phrases remain indivisible, so a phrase longer than the cap
// gets a chunk of its own.
export function buildChunks(phraseGroups: WordEntry[][]): WordEntry[][] {
  const chunks: WordEntry[][] = [];
  for (const group of phraseGroups) {
    const last = chunks.at(-1);
    if (last && last.length + group.length <= LINES_PER_CHUNK) {
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

// Throw when too much of a chunk came back as the source word.
//
// Three parts of speech are left out of the count entirely, because for them
// coming back unchanged is the right answer rather than a failure: punctuation
// (rule 5 asks for it), numerals, and proper nouns. Everything else counts,
// including cognates and loanwords — "hotel" translating to "hotel" is real,
// but it is rare enough across a 200-line chunk that it cannot reach the bar
// on its own.
const ECHO_EXEMPT_PARTS_OF_SPEECH = new Set(["punctuation", "numeral", "proper_noun"]);

export function assertNotEchoed(sourceWords: string[], translations: string[]): void {
  let counted = 0;
  let echoed = 0;

  sourceWords.forEach((word, index) => {
    const translated = translations[index] ?? "";
    if (ECHO_EXEMPT_PARTS_OF_SPEECH.has(partOfSpeechOf(translated))) return;

    const source = normalizeForEcho(word);
    const translation = normalizeForEcho(stripPartOfSpeech(translated));
    if (source === "" || translation === "") return;

    counted += 1;
    if (source === translation) echoed += 1;
  });

  if (counted < MIN_ECHO_SAMPLE) return;
  const ratio = echoed / counted;
  if (ratio < MAX_ECHO_RATIO) return;

  throw new Error(
    `Word translations echo the source language: ${echoed}/${counted} words came back unchanged`,
  );
}

function stripPartOfSpeech(translation: string): string {
  return translation.replace(/\s*\[[a-z_]+\]\s*$/i, "");
}

function partOfSpeechOf(translation: string): string {
  return translation.match(/\[([a-z_]+)\]\s*$/i)?.[1].toLowerCase() ?? "";
}

// Compare on what a reader would call the same word: case, surrounding
// punctuation and quoting differences are not a translation.
function normalizeForEcho(value: string): string {
  return value
    .normalize("NFC")
    .toLowerCase()
    .replace(/^[\p{P}\p{S}\s]+|[\p{P}\p{S}\s]+$/gu, "");
}
