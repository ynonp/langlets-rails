import { assert, assertEquals, assertFalse, assertThrows } from "@std/assert";
import { applyOp, ProgressStore } from "../src/progress.ts";
import { MemorySink } from "../src/callback.ts";
import type { ProgressData } from "../src/types.ts";
import { HEBREW, phrasesFixture } from "./helpers.ts";

Deno.test("applyOp sets nested paths, creating containers on demand", () => {
  const data: ProgressData = {};
  applyOp(data, { op: "set", path: "translations.he.phrases.1.text", value: "שלום" });

  // deno-lint-ignore no-explicit-any
  const translations = data.translations as any;
  assertEquals(translations.he.phrases[1].text, "שלום");
  // Index 0 was auto-created as an empty slot in the array.
  assertEquals(translations.he.phrases.length, 2);
});

Deno.test("applyOp set overwrites scalars and objects", () => {
  const data: ProgressData = { lessons: "old" };
  applyOp(data, { op: "set", path: "lessons", value: "new" });
  assertEquals(data.lessons, "new");
});

Deno.test("applyOp append creates the array and pushes", () => {
  const data: ProgressData = {};
  applyOp(data, { op: "append", path: "errors", value: { step: "x" } });
  applyOp(data, { op: "append", path: "errors", value: { step: "y" } });
  assertEquals(data.errors?.length, 2);
  assertEquals(data.errors?.[1].step, "y");
});

Deno.test("applyOp append onto a non-array throws", () => {
  const data: ProgressData = { lessons: "text" };
  assertThrows(() => applyOp(data, { op: "append", path: "lessons", value: 1 }));
});

Deno.test("applyOp clear_errors removes only failures for the recovered step", () => {
  const data: ProgressData = {
    errors: [
      { step: "translate", occurred_at: "then", error_message: "old" },
      { step: "rate_lessons", occurred_at: "now", error_message: "current" },
      { step: "translate", occurred_at: "later", error_message: "also old" },
    ],
  };

  applyOp(data, { op: "clear_errors", path: "errors", value: "translate" });

  assertEquals(data.errors?.map((error) => error.step), ["rate_lessons"]);
});

Deno.test("applyOp rejects empty path segments", () => {
  assertThrows(() => applyOp({}, { op: "set", path: "a..b", value: 1 }));
});

Deno.test("store mutations apply locally and forward the same ops to the sink", async () => {
  const sink = new MemorySink();
  const store = new ProgressStore({}, sink);

  await store.set("video_length_seconds", 225);
  await store.append("errors", { step: "translate" });
  await store.clearErrors("translate");

  assertEquals(store.data.video_length_seconds, 225);
  assertEquals(store.data.errors?.length, 0);
  assertEquals(sink.ops, [
    { op: "set", path: "video_length_seconds", value: 225 },
    { op: "append", path: "errors", value: { step: "translate" } },
    { op: "clear_errors", path: "errors", value: "translate" },
  ]);
});

Deno.test("extractLyricsDone requires lyric lines and a cleared in-progress flag", () => {
  const sink = new MemorySink();
  const lines = ["Bonjour le monde", "Salut encore"];

  assertFalse(new ProgressStore({}, sink).extractLyricsDone());
  assert(new ProgressStore({ lyric_lines: lines }, sink).extractLyricsDone());
  assertFalse(
    new ProgressStore(
      { lyric_lines: lines, extract_lyrics_in_progress: true },
      sink,
    ).extractLyricsDone(),
  );
  // Data saved before the extract/align split has phrases but no lyric lines:
  // its transcription counts as done.
  assert(new ProgressStore({ phrases: phrasesFixture() }, sink).extractLyricsDone());
  assertFalse(
    new ProgressStore(
      { phrases: phrasesFixture(), extract_lyrics_in_progress: true },
      sink,
    ).extractLyricsDone(),
  );
});

Deno.test("forceAlignmentDone requires phrases and a cleared in-progress flag", () => {
  const sink = new MemorySink();
  assertFalse(new ProgressStore({}, sink).forceAlignmentDone());
  // Lines that were never timed aren't enough.
  assertFalse(new ProgressStore({ lyric_lines: ["Bonjour"] }, sink).forceAlignmentDone());
  assert(new ProgressStore({ phrases: phrasesFixture() }, sink).forceAlignmentDone());
  // A fresh transcription marks the old phrases as stale.
  assertFalse(
    new ProgressStore(
      { phrases: phrasesFixture(), force_alignment_in_progress: true },
      sink,
    ).forceAlignmentDone(),
  );
});

Deno.test("translateDone requires every phrase text in the language payload", () => {
  const sink = new MemorySink();
  const store = new ProgressStore({
    phrases: phrasesFixture(),
    translations: {
      he: {
        language_id: HEBREW.id,
        language_name: HEBREW.english_name,
        phrases: [
          { text: "שלום עולם", words: [null, null] },
          { text: null, words: [null, null] },
        ],
        lessons: null,
      },
    },
  }, sink);

  assertFalse(store.translateDone("he"));
  store.data.translations!.he.phrases[1].text = "שוב שלום";
  assert(store.translateDone("he"));
  assertFalse(store.translateDone("en"));
});

Deno.test("translationLinesDone validates the pre-alignment line count", () => {
  const sink = new MemorySink();
  assertFalse(new ProgressStore({ lyric_lines: ["one", "two"] }, sink).translationLinesDone("he"));
  assertFalse(
    new ProgressStore(
      { lyric_lines: ["one", "two"], translation_lines: { he: ["אחד"] } },
      sink,
    ).translationLinesDone("he"),
  );
  assert(
    new ProgressStore(
      { lyric_lines: ["one", "two"], translation_lines: { he: ["אחד", "שתיים"] } },
      sink,
    ).translationLinesDone("he"),
  );
});

Deno.test("tokenTranslationsDone tracks per-phrase completion", () => {
  const sink = new MemorySink();
  const store = new ProgressStore({
    phrases: phrasesFixture(),
    translations: {
      he: {
        language_id: HEBREW.id,
        language_name: HEBREW.english_name,
        phrases: [
          { text: null, words: ["שלום", "עולם"] },
          { text: null, words: ["היי", null] },
        ],
        lessons: null,
      },
    },
  }, sink);

  assert(store.tokenTranslationsDoneFor("he", 0));
  assertFalse(store.tokenTranslationsDoneFor("he", 1));
  assertFalse(store.tokenTranslationsDone("he"));

  store.data.translations!.he.phrases[1].words = ["היי", "עוד"];
  assert(store.tokenTranslationsDone("he"));
});

Deno.test("lesson guards mirror the Rails predicates", () => {
  const sink = new MemorySink();
  const store = new ProgressStore({}, sink);
  assertFalse(store.lessonsDone());
  assertFalse(store.lessonsRated());

  store.data.lessons = "# Title\nLine";
  store.data.lesson_ratings = [{ index: 1, title: "Title", score: 4, reason: "ok" }];
  assert(store.lessonsDone());
  assert(store.lessonsRated());
});
