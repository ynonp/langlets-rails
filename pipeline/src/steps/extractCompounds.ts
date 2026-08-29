import { generateText } from "ai";
import type { Phrase, Word } from "../types.ts";
import type { PipelineContext } from "../context.ts";
import { clearErrors } from "../context.ts";
import { extractCompoundsPrompt } from "../prompts/extractCompounds.ts";
import { message, withRetries } from "../retry.ts";

export const LEARNER_TOKENIZATION_VERSION = 1;
const MAX_RETRIES = 1;

interface LocatedWord {
  phraseIndex: number;
  word: Word;
}

export async function extractCompounds(ctx: PipelineContext): Promise<void> {
  const phrases = ctx.store.data.phrases ?? [];
  const sourceWords = locateWords(phrases);
  if (sourceWords.length === 0) {
    await ctx.store.set("learner_tokenization_version", LEARNER_TOKENIZATION_VERSION);
    return;
  }

  const transcript = phrases
    .map((phrase) => phrase.words.map((word) => word.text).join(" "))
    .join("\n");
  let lastResponse: string | null = null;

  try {
    const tokenizedPhrases = await withRetries(
      async () => {
        const { text } = await generateText({
          model: ctx.models.extractCompounds,
          system: extractCompoundsPrompt(ctx.clipLanguage),
          prompt: transcript,
          temperature: 0,
        });
        lastResponse = text;
        return materializeLearnerTokens(phrases, parseTokenArray(text));
      },
      {
        maxRetries: MAX_RETRIES,
        label: "ExtractCompounds",
        baseDelayMs: ctx.baseDelayMs,
      },
    );

    await ctx.store.patch([
      { op: "set", path: "phrases", value: tokenizedPhrases },
      {
        op: "set",
        path: "learner_tokenization_version",
        value: LEARNER_TOKENIZATION_VERSION,
      },
    ]);
    await clearErrors(ctx, "extract_compounds");
  } catch (error) {
    // Compound extraction improves learner tokens but is not allowed to block
    // an otherwise valid course. Preserve the original words and stamp the
    // pass complete so a resume does not repeatedly spend another model call.
    // data.errors is terminal on the Rails side: its callback immediately asks
    // Imports::Finalizer to fail active requests. This step has a valid identity
    // fallback, so log its diagnostic without reporting a pipeline failure.
    console.warn(
      `ExtractCompounds kept the original learner tokens after invalid output: ${message(error)}` +
        (lastResponse ? `\nLast response: ${lastResponse}` : ""),
    );
    await ctx.store.set("learner_tokenization_version", LEARNER_TOKENIZATION_VERSION);
  }
}

export function parseTokenArray(content: string): string[] {
  const start = content.indexOf("[");
  const end = content.lastIndexOf("]");
  if (start < 0 || end < start) throw new Error("Compound response does not contain a JSON array");

  let parsed: unknown;
  try {
    parsed = JSON.parse(content.slice(start, end + 1));
  } catch {
    throw new Error("Compound response contains invalid JSON");
  }
  if (!Array.isArray(parsed) || parsed.some((item) => typeof item !== "string" || item === "")) {
    throw new Error("Compound response must be an array of non-empty strings");
  }
  return parsed;
}

export function materializeLearnerTokens(phrases: Phrase[], returnedTokens: string[]): Phrase[] {
  const source = locateWords(phrases);
  const wordsByPhrase: Word[][] = phrases.map(() => []);
  let cursor = 0;

  for (const returnedToken of returnedTokens) {
    if (/^\s|\s$/u.test(returnedToken) || /\s{2,}/u.test(returnedToken)) {
      throw new Error(`Compound token has changed whitespace: ${JSON.stringify(returnedToken)}`);
    }

    const group: LocatedWord[] = [];
    let reconstructed = "";
    while (cursor < source.length) {
      const candidate = source[cursor];
      const next = reconstructed === ""
        ? candidate.word.text
        : `${reconstructed} ${candidate.word.text}`;
      if (returnedToken !== next && !returnedToken.startsWith(`${next} `)) break;

      group.push(candidate);
      reconstructed = next;
      cursor += 1;
      if (reconstructed === returnedToken) break;
    }

    if (group.length === 0 || reconstructed !== returnedToken) {
      const expected = source[cursor]?.word.text ?? "end of transcript";
      throw new Error(
        `Compound token ${JSON.stringify(returnedToken)} does not match source word ${
          JSON.stringify(expected)
        }`,
      );
    }
    if (group.some((entry) => entry.phraseIndex !== group[0].phraseIndex)) {
      throw new Error(`Compound token crosses a lesson line: ${JSON.stringify(returnedToken)}`);
    }

    wordsByPhrase[group[0].phraseIndex].push(mergeWords(group.map((entry) => entry.word)));
  }

  if (cursor !== source.length) {
    throw new Error(`Compound response covered ${cursor} of ${source.length} source words`);
  }

  return phrases.map((phrase, phraseIndex) => ({
    ...phrase,
    words: wordsByPhrase[phraseIndex],
  }));
}

function locateWords(phrases: Phrase[]): LocatedWord[] {
  return phrases.flatMap((phrase, phraseIndex) =>
    phrase.words.map((word) => ({ phraseIndex, word }))
  );
}

function mergeWords(words: Word[]): Word {
  const first = words[0];
  const firstTimed = words.find((word) => word.timestamp !== undefined);
  const lastTimed = [...words].reverse().find((word) => word.timestamp_end !== undefined);
  const firstIndexed = words.find((word) => word.l1_start_index !== undefined);
  const lastIndexed = [...words].reverse().find((word) => word.l1_end_index !== undefined);
  return {
    ...first,
    text: words.map((word) => word.text).join(" "),
    timestamp: firstTimed?.timestamp,
    timestamp_end: lastTimed?.timestamp_end,
    l1_start_index: firstIndexed?.l1_start_index,
    l1_end_index: lastIndexed?.l1_end_index,
  };
}
