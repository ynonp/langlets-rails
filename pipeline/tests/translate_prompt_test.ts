import { assertEquals, assertStringIncludes } from "@std/assert";
import { translatePrompt } from "../src/prompts/translate.ts";

function exampleInputOf(prompt: string): string {
  const [, afterHeading] = prompt.split("## Example input\n\n");
  const [input] = afterHeading.split("\n\n## Example output");
  return input;
}

Deno.test("translatePrompt uses the exact pair's example when one exists", () => {
  const prompt = translatePrompt("Arabic", "Hebrew", 3);

  assertStringIncludes(prompt, "أنا سعيد جدًا لسماع صوتك، حتى وأنا نائم");
  assertStringIncludes(prompt, "כל כך שמח לשמוע את קולך, גם כשאני ישן");
});

Deno.test("translatePrompt covers every configured language pair", () => {
  const pairs: Array<[string, string]> = [
    ["Arabic", "Hebrew"],
    ["Arabic", "English"],
    ["Spanish", "English"],
    ["Spanish", "Hebrew"],
    ["French", "English"],
    ["French", "Hebrew"],
  ];

  for (const [clip, translation] of pairs) {
    const prompt = translatePrompt(clip, translation, 3);
    // Each configured pair's own text shows up rather than the Spanish
    // fallback leaking in for a pair that has a dedicated example.
    if (clip !== "Spanish") {
      assertEquals(exampleInputOf(prompt).includes("Me alegra tanto"), false);
    }
  }
});

Deno.test("translatePrompt falls back to Spanish->Hebrew for an unlisted pair targeting Hebrew", () => {
  const prompt = translatePrompt("German", "Hebrew", 3);

  assertStringIncludes(prompt, "Me alegra tanto oír tu voz");
  assertStringIncludes(prompt, "כל כך שמח לשמוע את קולך, גם כשאני ישן");
});

Deno.test("translatePrompt falls back to Spanish->English for an unlisted pair targeting English", () => {
  const prompt = translatePrompt("German", "English", 3);

  assertStringIncludes(prompt, "Me alegra tanto oír tu voz");
  assertStringIncludes(prompt, "It makes me so happy to hear your voice");
});

Deno.test("translatePrompt falls back to Spanish->English for an unlisted pair targeting a third language", () => {
  const prompt = translatePrompt("German", "Italian", 3);

  assertStringIncludes(prompt, "Me alegra tanto oír tu voz");
  assertStringIncludes(prompt, "It makes me so happy to hear your voice");
});

Deno.test("translatePrompt threads clip/translation language names and line count into the instructions", () => {
  const prompt = translatePrompt("Arabic", "Hebrew", 7);

  assertStringIncludes(prompt, "Translate these Arabic subtitles into Hebrew.");
  assertStringIncludes(prompt, "idiomatic Hebrew in the word order");
  assertStringIncludes(prompt, "Output exactly 7 lines");
});
