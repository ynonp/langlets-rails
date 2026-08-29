import { assertEquals, assertStringIncludes } from "@std/assert";
import { exampleFor, extractCompoundsPrompt } from "../src/prompts/extractCompounds.ts";

Deno.test("extractCompoundsPrompt uses a source-language example", () => {
  const prompt = extractCompoundsPrompt("Arabic");

  assertStringIncludes(prompt, "قابل رئيس الوزراء وزير الخارجية");
  assertStringIncludes(prompt, '"رئيس الوزراء","وزير الخارجية"');
});

Deno.test("compound examples accept names and ISO codes and fall back to English", () => {
  assertEquals(exampleFor("ar"), exampleFor("Arabic"));
  assertEquals(exampleFor("Klingon"), exampleFor("English"));
});
