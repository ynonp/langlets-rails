import { assert, assertEquals, assertStringIncludes } from "@std/assert";
import { dictionaryFor, langCodeFor } from "../src/fuzzyword.ts";
import { exampleFor as lessonExample } from "../src/prompts/addLessons.ts";
import { addTokenTranslationsPrompt } from "../src/prompts/addTokenTranslations.ts";
import { exampleFor as compoundExample } from "../src/prompts/extractCompounds.ts";
import { geminiTimedTranscriptPrompt } from "../src/prompts/geminiTimedTranscript.ts";
import { translatePrompt } from "../src/prompts/translate.ts";
import {
  languageCodeForTranscription,
  segmentJapaneseCaption,
} from "../src/steps/extractLyrics.ts";

Deno.test("Japanese captions provide word boundaries and retain the source script", () => {
  const source = "昨日は映画を見ました。 カフェでコーヒーを飲んだ。";
  const segmented = segmentJapaneseCaption(source);
  assertStringIncludes(segmented, "昨日 は 映画 を");
  assertStringIncludes(segmented, "カフェ で コーヒー を");
  assertEquals(segmented.replaceAll(" ", ""), source.replaceAll(" ", ""));
  assertEquals(languageCodeForTranscription("Japanese"), "ja");
  assertEquals(languageCodeForTranscription("Japanese", "ja"), "ja");
  assertStringIncludes(geminiTimedTranscriptPrompt("Japanese"), "昨日, は, 映画, を, 見ました。");
});

Deno.test("Japanese examples preserve timed source tokens and demonstrate the requested target", () => {
  const lesson = lessonExample("Japanese");
  assertEquals(lesson.lessons.flatMap(({ lines }) => lines).join(" "), lesson.input);
  const compound = compoundExample("ja-JP");
  assertEquals(compound.output.join(" "), compound.input.replaceAll("\n", " "));
  assertStringIncludes(
    addTokenTranslationsPrompt("Japanese", "English"),
    "topic marker [particle]",
  );
  assertStringIncludes(addTokenTranslationsPrompt("French", "Japanese"), "映画 [noun]");
  assertStringIncludes(translatePrompt("French", "Japanese", 3), "あなたの声");
  assertStringIncludes(translatePrompt("Japanese", "English", 3), "hear your voice");
});

Deno.test("Japanese similar sounds support short words and skip homophones", async () => {
  const code = langCodeFor("Japanese");
  assertEquals(code, "ja");
  const dictionary = await dictionaryFor(code!);
  assert(dictionary);
  assertEquals(dictionary.lookup("映画"), ["英語"]);
  assertEquals(dictionary.lookup("雨"), ["亀"]);
  assertEquals(dictionary.lookup("あめ"), ["亀"]);
  assertEquals(dictionary.lookup("昨日"), []);
});
