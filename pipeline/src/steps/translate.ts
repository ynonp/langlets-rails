// The target language picks the model: models.translateOverrides[iso] when the
// registry has one (Hebrew), otherwise models.translate.
//
// The result is persisted at translation_lines.<iso>;
// materializeTranslationLines copies it into the stable v2
// translations.<iso>.phrases shape.
//
// The 1:1 line mapping is carried by explicit line numbers rather than by the
// shape of the response (see prompts/translate.ts for why). That turns "the
// count is wrong" into "these lines are missing", which is a repairable
// failure: whatever came back correctly numbered is kept, and the next attempt
// asks only for the gaps — with the whole chunk still in the prompt as
// context, so a one-word fragment is never translated in isolation.

import { generateText } from "ai";
import type { LanguageModel } from "ai";
import type { PipelineContext } from "../context.ts";
import { clearErrors, recordError } from "../context.ts";
import { translatePrompt } from "../prompts/translate.ts";
import { mapWithConcurrency } from "../concurrency.ts";

// Soft cap on source lines per LLM call. Long transcripts drift the further
// the model gets from the top of its own output, and a mismatch in one chunk
// is repaired without re-asking for the rest.
export const LINES_PER_CHUNK = 200;

const MAX_CONCURRENCY = 4;

// One full pass plus two repair passes. A repair pass is cheap — it asks for
// only the handful of lines that went missing — so this costs far less than
// the count it looks like.
export const MAX_ATTEMPTS = 3;

// A response that repeats the source lines instead of translating them
// satisfies the numbering — the same gap addTokenTranslations.ts's
// assertNotEchoed closes for word translations. Guard the sentence level the
// same way: too many lines coming back unchanged is a bad response, not a
// real translation. Kept as its own copy rather than shared with
// addTokenTranslations.ts's version — that one judges words against a part-
// of-speech exemption list that has no equivalent at the line level.
export const MAX_ECHO_RATIO = 0.3;
export const MIN_ECHO_SAMPLE = 8;

// A source line and the 1-based number the model sees it under. Numbering is
// global across chunks, so a line number identifies a line in the whole
// transcript and chunk boundaries never renumber anything.
export interface SourceLine {
  number: number;
  text: string;
}

export async function translate(ctx: PipelineContext): Promise<void> {
  const language = ctx.translationLanguage;
  if (!language) return;

  const model = ctx.models.translateOverrides?.[language.iso_name] ?? ctx.models.translate;

  const originalLyrics = ctx.store.data.lyric_lines ??
    (ctx.store.data.phrases ?? []).map((phrase) => phrase.text_l1);
  const sourceLines: SourceLine[] = originalLyrics.map((text, index) => ({
    number: index + 1,
    text,
  }));

  const chunks = buildChunks(sourceLines);
  const results = await mapWithConcurrency(
    chunks,
    MAX_CONCURRENCY,
    (chunk) => translateChunk(ctx, model, language.english_name, chunk),
  );

  const failure = results.find((r) => r.status === "rejected");
  if (failure) throw (failure as PromiseRejectedResult).reason;

  const translated = new Map<number, string>();
  for (const result of results) {
    if (result.status !== "fulfilled") continue;
    for (const [number, text] of result.value) translated.set(number, text);
  }
  const translationLines = sourceLines.map((line) => translated.get(line.number) ?? "");

  // Every chunk passed its own echo check, but a transcript chopped into
  // chunks too small to judge individually can still come back wholesale in
  // the source language. Judge the assembled result once more.
  try {
    assertLinesNotEchoed(originalLyrics, translationLines);
  } catch (error) {
    await recordError(ctx, "translate", error, { input_lines: originalLyrics });
    throw error;
  }

  await ctx.store.set(
    `translation_lines.${language.iso_name}`,
    translationLines.map((text) => text.replaceAll("[", "(").replaceAll("]", ")")),
  );
  await clearErrors(ctx, "translate");
}

// Translate one chunk, repairing missing lines in place. Resolves with the
// chunk's line number -> translation map, or throws once the attempts are
// spent with lines still missing.
async function translateChunk(
  ctx: PipelineContext,
  model: LanguageModel,
  targetLanguage: string,
  chunk: SourceLine[],
): Promise<Map<number, string>> {
  const translated = new Map<number, string>();

  // A blank source line has no translation to ask for, and asking anyway
  // guarantees a "missing" line the model can never supply. Fill it here and
  // leave it in the prompt as context.
  for (const line of chunk) {
    if (line.text.trim() === "") translated.set(line.number, line.text);
  }

  const input = chunk.map((line) => `${line.number}. ${line.text}`).join("\n");
  let lastResponse: string | null = null;
  let lastError: unknown = null;
  let attempts = 0;

  while (attempts < MAX_ATTEMPTS) {
    const missing = chunk.filter((line) => !translated.has(line.number));
    if (missing.length === 0) break;
    attempts += 1;

    try {
      const { text } = await generateText({
        model,
        system: translatePrompt(
          ctx.clipLanguage,
          targetLanguage,
          missing.length,
          // The first pass over an all-blank-free chunk wants everything, so
          // it asks for everything; anything narrower names its lines.
          missing.length === chunk.length ? undefined : missing.map((line) => line.number),
        ),
        prompt: input,
        temperature: 0.2,
        // deepseek-v4-pro is a thinking model and reasons by default, spending
        // ~10x the output tokens and ~8x the wall time to reach the same
        // translation. The key must be the provider name from models.ts and
        // camelCase; `reasoning_effort` is silently dropped by the SDK. Other
        // providers ignore an unknown key, so this is safe if the model changes.
        providerOptions: { ollama: { reasoningEffort: "none" } },
      });
      lastResponse = text;

      const returned = parseNumberedLines(text, missing);
      // Echoed output is a misunderstood task, not a partial answer: drop the
      // whole response rather than bank lines from it.
      assertLinesNotEchoed(
        [...returned.keys()].map((number) => sourceTextOf(chunk, number)),
        [...returned.values()],
      );
      for (const [number, translation] of returned) translated.set(number, translation);
    } catch (error) {
      lastError = error;
    }

    if (chunk.every((line) => translated.has(line.number))) break;
    if (attempts < MAX_ATTEMPTS) await backoff(attempts, ctx.baseDelayMs);
  }

  const missing = chunk.filter((line) => !translated.has(line.number));
  if (missing.length === 0) return translated;

  // Nothing survived any attempt: whatever the last one threw explains it
  // better than a "0 of N lines came back" count would.
  const error = translated.size === 0 && lastError ? lastError : new Error(
    `Bad translation, ${missing.length} of ${chunk.length} lines missing after ` +
      `${attempts} attempts: ${describeMissing(missing)}`,
  );

  await recordError(ctx, "translate", error, {
    attempts,
    input_lines: chunk.map((line) => line.text),
    agent_response: lastResponse,
  });
  throw error;
}

// Pack source lines into chunks of at most LINES_PER_CHUNK, in order.
export function buildChunks(sourceLines: SourceLine[]): SourceLine[][] {
  const chunks: SourceLine[][] = [];
  for (let at = 0; at < sourceLines.length; at += LINES_PER_CHUNK) {
    chunks.push(sourceLines.slice(at, at + LINES_PER_CHUNK));
  }
  return chunks;
}

// "12. שלום עולם" -> 12 => "שלום עולם", keeping only the numbers this pass
// asked for. Everything else is dropped on purpose: an unnumbered line is
// commentary or the tail of a merge, a number outside `requested` is the model
// re-translating context, and a repeated number is it losing its place — in
// every case the first correctly numbered answer is the one to trust.
const NUMBERED_LINE = /^\s*(\d+)\s*[.)\]:-]\s*(.+)$/;

export function parseNumberedLines(
  content: string,
  requested: SourceLine[],
): Map<number, string> {
  const wanted = new Set(requested.map((line) => line.number));
  const translations = new Map<number, string>();

  for (const raw of content.split("\n")) {
    const match = raw.replace(/\s+$/, "").match(NUMBERED_LINE);
    if (!match) continue;

    const number = Number(match[1]);
    const text = match[2].trim();
    if (text === "" || !wanted.has(number) || translations.has(number)) continue;

    translations.set(number, text);
  }

  return translations;
}

// Throw when too much of the response came back as the source line. Some
// echo is legitimate — a line that's just a proper name, a number, or an
// interjection can translate to itself — which is why the bar is a ratio
// over the whole response rather than a single line, and why a clip too
// short for the ratio to mean anything is never failed on it.
export function assertLinesNotEchoed(sourceLines: string[], translatedLines: string[]): void {
  let counted = 0;
  let echoed = 0;

  sourceLines.forEach((line, index) => {
    const source = normalizeForEcho(line);
    const translation = normalizeForEcho(translatedLines[index] ?? "");
    if (source === "" || translation === "") return;

    counted += 1;
    if (source === translation) echoed += 1;
  });

  if (counted < MIN_ECHO_SAMPLE) return;
  const ratio = echoed / counted;
  if (ratio < MAX_ECHO_RATIO) return;

  throw new Error(
    `Translated lines echo the source language: ${echoed}/${counted} lines came back unchanged`,
  );
}

function sourceTextOf(chunk: SourceLine[], number: number): string {
  return chunk.find((line) => line.number === number)?.text ?? "";
}

// Name the first few gaps outright — with line numbers the failure points at
// the exact lines to look at in agent_response, which is the whole reason for
// numbering them.
function describeMissing(missing: SourceLine[]): string {
  const shown = missing.slice(0, 10).map((line) => line.number).join(", ");
  return missing.length > 10 ? `${shown}, ...` : shown;
}

// Matches retry.ts's schedule: (2 ** attempt) + rand(1..3) seconds, scaled by
// baseDelayMs so tests run at zero delay.
function backoff(attempt: number, baseDelayMs: number): Promise<void> {
  const waitSeconds = 2 ** attempt + (1 + Math.random() * 2);
  console.warn(
    `Translate attempt ${attempt} left lines missing. Retrying in ${waitSeconds.toFixed(1)}s...`,
  );
  return new Promise((resolve) => setTimeout(resolve, waitSeconds * baseDelayMs));
}

// Mirrors addTokenTranslations.ts's normalizeForEcho: case, surrounding
// punctuation and quoting differences are not a translation.
function normalizeForEcho(value: string): string {
  return value
    .normalize("NFC")
    .toLowerCase()
    .replace(/^[\p{P}\p{S}\s]+|[\p{P}\p{S}\s]+$/gu, "");
}
