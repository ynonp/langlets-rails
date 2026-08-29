import { parseArgs } from "jsr:@std/cli@^1.0.0/parse-args";
import { defaultModels } from "../src/models.ts";
import { ProgressStore } from "../src/progress.ts";
import type { PatchOp, Phrase, ProgressData } from "../src/types.ts";
import type { ProgressSink } from "../src/types.ts";
import type { PipelineContext } from "../src/context.ts";
import { extractCompounds } from "../src/steps/extractCompounds.ts";
import { addTokenTranslations } from "../src/steps/addTokenTranslations.ts";
import { initTranslationPayload } from "../src/steps/finalizeTranslation.ts";
import {
  addTokenTranslationsPrompt,
  legacyAddTokenTranslationsPrompt,
} from "../src/prompts/addTokenTranslations.ts";
import { capitalizeSentence } from "../src/learnerTokens.ts";

const ROOSEVELT_LINES = [
  "the United States was at peace with that nation",
  "and at the solicitation of Japan was still in conversation with its government and its Emperor",
  "looking toward the maintenance of Peace in the Pacific",
  "the attack yesterday on the Hawaiian Islands has caused severe damage to American naval and military forces",
];

const EDGE_CASE_LINES = [
  "at the request of France its government remained in talks with its President",
  "the committee was in charge of its maintenance and its operation",
  "she spoke with the owner of the company about its future",
  "after the agreement Japan continued its conversation with the United States",
  "the minister called on its allies to maintain peace in the region",
];

class MemorySink implements ProgressSink {
  async patch(_ops: PatchOp[]): Promise<void> {}
}

const args = parseArgs(Deno.args, {
  string: ["prompt", "sample"],
  default: { prompt: "both", sample: "roosevelt" },
});
if (!["both", "legacy", "current"].includes(args.prompt)) {
  usage();
}
if (!["roosevelt", "edge-cases", "all"].includes(args.sample)) {
  usage();
}

function usage(): never {
  console.error(
    "usage: deno task compare:roosevelt [--prompt both|legacy|current] " +
      "[--sample roosevelt|edge-cases|all]",
  );
  Deno.exit(1);
}

const variants = args.prompt === "both"
  ? [["legacy", legacyAddTokenTranslationsPrompt], ["current", addTokenTranslationsPrompt]] as const
  : args.prompt === "legacy"
  ? [["legacy", legacyAddTokenTranslationsPrompt]] as const
  : [["current", addTokenTranslationsPrompt]] as const;

const lines = args.sample === "roosevelt"
  ? ROOSEVELT_LINES
  : args.sample === "edge-cases"
  ? EDGE_CASE_LINES
  : [...ROOSEVELT_LINES, ...EDGE_CASE_LINES];
const rawPhrases = phrasesFor(lines);
const tokenizationStore = new ProgressStore(
  { phrases: rawPhrases, lyric_lines: rawPhrases.map((phrase) => phrase.text_l1) },
  new MemorySink(),
);
await extractCompounds({
  store: tokenizationStore,
  models: defaultModels(),
  youtubeurl: "diagnostic://roosevelt",
  clipLanguage: "English",
  translationLanguage: { id: null, iso_name: "he", english_name: "Hebrew" },
  baseDelayMs: 1,
});
const learnerPhrases = tokenizationStore.data.phrases!;

for (const [name, prompt] of variants) {
  const phrases = structuredClone(learnerPhrases);
  const data: ProgressData = { phrases, lyric_lines: phrases.map((phrase) => phrase.text_l1) };
  const store = new ProgressStore(data, new MemorySink());
  const ctx: PipelineContext = {
    store,
    models: defaultModels(),
    youtubeurl: "diagnostic://roosevelt",
    clipLanguage: "English",
    translationLanguage: { id: null, iso_name: "he", english_name: "Hebrew" },
    baseDelayMs: 1,
  };
  await initTranslationPayload(ctx);
  await addTokenTranslations(ctx, prompt);

  console.log(`\n=== ${name} prompt ===`);
  const translated = store.data.translations!.he.phrases;
  store.data.phrases!.forEach((phrase, phraseIndex) => {
    console.log(phrase.text_l1);
    phrase.words.forEach((word, wordIndex) => {
      const gloss = translated[phraseIndex].words[wordIndex]?.replace(/\s*\[[a-z_]+\]\s*$/i, "");
      console.log(`${word.text} -> ${gloss}`);
    });
    console.log("");
  });
}

function phrasesFor(lines: string[]): Phrase[] {
  return lines.map((rawLine, index) => {
    const line = capitalizeSentence(rawLine);
    const words = line.split(/\s+/u).map((text) => ({ text }));
    return {
      id: `phrase_${index + 1}`,
      text_l1: words.map((word) => word.text).join(" "),
      timestamp: "00:00.00",
      timestamp_end: "00:00.00",
      words,
    };
  });
}
