import { assertEquals, assertFalse, assertStringIncludes } from "@std/assert";
import { addLessonsPrompt, exampleFor } from "../src/prompts/addLessons.ts";

const LANGUAGES = [
  ["English", "en"],
  ["Spanish", "es"],
  ["French", "fr"],
  ["German", "de"],
  ["Hebrew", "he"],
  ["Russian", "ru"],
  ["Arabic", "ar"],
] as const;

for (const [name, iso] of LANGUAGES) {
  Deno.test(`add-lessons prompt has a complete ${name} example`, () => {
    const example = exampleFor(name);
    assertEquals(example, exampleFor(iso));
    assertFalse(example.input.includes("\n"));

    const content = example.lessons.flatMap((lesson) => lesson.lines);
    assertEquals(example.lessons.length, 2);
    assertEquals(content.length, 10);
    assertEquals(content.join(" "), example.input);

    const prompt = addLessonsPrompt(name, "English");
    assertStringIncludes(prompt, example.input);
    assertStringIncludes(prompt, JSON.stringify(example.lessons[0].lines[0]));
  });
}

Deno.test("unknown clip languages use the English example", () => {
  assertEquals(exampleFor("Klingon"), exampleFor("English"));
});
