import { assertEquals } from "@std/assert";
import { reconcileTimedTranscript } from "../src/reconcileTimedTranscript.ts";

const timed = (text: string[]) =>
  text.map((word, index) => ({ text: word, start: index, end: index + 0.75 }));

Deno.test("keeps exact Scribe timings for unchanged reconciled words", () => {
  const source = timed(["Hello", "world"]);
  const result = reconcileTimedTranscript("hello world!", source);

  assertEquals(result.words, [
    { text: "hello", start: 0, end: 0.75 },
    { text: "world!", start: 1, end: 1.75 },
  ]);
  assertEquals(result.fallbackSpans, 0);
});

Deno.test("maps a local one-word correction onto its original time span", () => {
  const result = reconcileTimedTranscript(
    "دائماً بنتابع والله",
    timed(["دائماً", "بنتبه", "والله"]),
  );

  assertEquals(result.words, [
    { text: "دائماً", start: 0, end: 0.75 },
    { text: "بنتابع", start: 1, end: 1.75 },
    { text: "والله", start: 2, end: 2.75 },
  ]);
  assertEquals(result.replacedSpans, 1);
});

Deno.test("splits one corrected name across the replaced Scribe span", () => {
  const result = reconcileTimedTranscript(
    "عند أبو أصيل حبيبي",
    timed(["عند", "أباصيل", "حبيبي"]),
  );

  assertEquals(result.words.map((word) => word.text), ["عند", "أبو", "أصيل", "حبيبي"]);
  assertEquals(result.words[1].start, 1);
  assertEquals(result.words[2].end, 1.75);
  assertEquals(result.replacedSpans, 1);
});

Deno.test("falls back to original timed words for insertions and broad rewrites", () => {
  const insertion = reconcileTimedTranscript(
    "one genuinely new two",
    timed(["one", "two"]),
  );
  assertEquals(insertion.words.map((word) => word.text), ["one", "two"]);
  assertEquals(insertion.fallbackSpans, 1);

  const rewrite = reconcileTimedTranscript(
    "completely rewritten transcript without shared anchors",
    timed(["Line", "1", "Line", "2"]),
  );
  assertEquals(rewrite.words, timed(["Line", "1", "Line", "2"]));
  assertEquals(rewrite.fallbackSpans, 1);
});
