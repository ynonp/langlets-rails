import { assertEquals, assertRejects } from "@std/assert";
import {
  isSameLanguage,
  MAX_LINE_LENGTH,
  transcribeWithSupadata,
  transcriptToLines,
  transcriptToText,
} from "../src/supadata.ts";

Deno.test("Supadata client sends a native timestamped transcript request", async () => {
  let requested: URL | null = null;
  const result = await transcribeWithSupadata("https://youtu.be/test", "fr", {
    apiKey: "secret",
    fetch: (input, init) => {
      requested = new URL(String(input));
      assertEquals(
        new Headers((init as globalThis.RequestInit | undefined)?.headers).get("x-api-key"),
        "secret",
      );
      return Promise.resolve(Response.json({
        content: [{ text: "Bonjour", offset: 1000, duration: 2000, lang: "fr" }],
        lang: "fr",
        availableLangs: ["fr"],
      }));
    },
  });

  assertEquals(requested!.pathname, "/v1/transcript");
  assertEquals(requested!.searchParams.get("mode"), "native");
  assertEquals(requested!.searchParams.get("text"), "false");
  assertEquals(requested!.searchParams.get("lang"), "fr");
  assertEquals(result.content.length, 1);
});

Deno.test("Supadata client polls asynchronous transcript jobs", async () => {
  const responses = [
    new Response(JSON.stringify({ jobId: "job-1" }), { status: 202 }),
    Response.json({ status: "active" }),
    Response.json({
      status: "completed",
      content: [{ text: "Salut", offset: 0, duration: 900, lang: "fr" }],
      lang: "fr",
      availableLangs: ["fr"],
    }),
  ];
  let calls = 0;
  const result = await transcribeWithSupadata("https://youtu.be/test", "fr", {
    apiKey: "secret",
    fetch: () => Promise.resolve(responses[calls++]),
    sleep: () => Promise.resolve(),
    pollIntervalMs: 0,
  });

  assertEquals(calls, 3);
  assertEquals(result.content[0].text, "Salut");
});

Deno.test("Supadata client surfaces API errors", async () => {
  await assertRejects(
    () =>
      transcribeWithSupadata("https://youtu.be/test", "fr", {
        apiKey: "secret",
        fetch: () =>
          Promise.resolve(Response.json({ error: { code: "unauthorized" } }, { status: 401 })),
      }),
    Error,
    "Supadata transcription failed (401)",
  );
});

Deno.test("transcript splitting prefers periods and commas and caps lines at 42 characters", () => {
  const lines = transcriptToLines([
    {
      text: "A short sentence. This clause is deliberately long, and needs another line",
      offset: 0,
      duration: 1,
      lang: "en",
    },
  ]);
  assertEquals(lines, [
    "A short sentence.",
    "This clause is deliberately long,",
    "and needs another line",
  ]);
  assertEquals(lines.every((line) => [...line].length <= MAX_LINE_LENGTH), true);
});

Deno.test("transcript splitting falls back to whitespace and hard-splits long tokens", () => {
  const longToken = "x".repeat(50);
  const lines = transcriptToLines([
    {
      text: `one two three four five six seven eight nine ten ${longToken}`,
      offset: 0,
      duration: 1,
      lang: "en",
    },
  ]);
  assertEquals(lines.every((line) => [...line].length <= MAX_LINE_LENGTH), true);
  assertEquals(
    lines.join(" ").replace(/\s+/gu, " "),
    `one two three four five six seven eight nine ten ${longToken.slice(0, 42)} ${
      longToken.slice(42)
    }`,
  );
});

Deno.test("native transcript splitting removes bracketed and parenthetical non-speech annotations", () => {
  const lines = transcriptToLines([
    { text: "Buenas noches,", offset: 0, duration: 1, lang: "es" },
    { text: "[Música]", offset: 1, duration: 1, lang: "es" },
    { text: "(pasos)", offset: 2, duration: 1, lang: "es" },
    { text: "[Aplausos]", offset: 3, duration: 1, lang: "es" },
    { text: "Hola [ruido] a (música intensa) todos.", offset: 4, duration: 1, lang: "es" },
  ]);

  assertEquals(lines, ["Buenas noches,", "Hola a todos."]);
});

Deno.test("continuous transcript text removes parenthetical non-speech annotations", () => {
  const text = transcriptToText([
    { text: "(footsteps clicking)", offset: 0, duration: 1, lang: "en" },
    { text: "Hello (door squeaks) everyone.", offset: 1, duration: 1, lang: "en" },
  ]);

  assertEquals(text, "Hello everyone.");
});

Deno.test("native transcript splitting removes the note symbols wrapping sung lines", () => {
  const lines = transcriptToLines([
    { text: "♪ You and me ♪", offset: 0, duration: 1, lang: "en" },
    { text: "♫ We used to be together ♬", offset: 1, duration: 1, lang: "en" },
  ]);

  assertEquals(lines, ["You and me", "We used to be together"]);
});

Deno.test("language comparison ignores the region subtag but not the language", () => {
  assertEquals(isSameLanguage("en", "en-US"), true);
  assertEquals(isSameLanguage("pt_BR", "PT"), true);
  assertEquals(isSameLanguage("ja", "en"), false);
});

Deno.test("native annotation removal preserves Hebrew and Arabic text and punctuation", () => {
  const lines = transcriptToLines([
    { text: "[מוזיקה]", offset: 0, duration: 1, lang: "he" },
    { text: "שָׁלוֹם, [מחיאות כפיים] לכולם!", offset: 1, duration: 1, lang: "he" },
    { text: "[موسيقى]", offset: 2, duration: 1, lang: "ar" },
    { text: "مرحبًا، [تصفيق] كيف حالكم؟", offset: 3, duration: 1, lang: "ar" },
  ]);

  assertEquals(lines, ["שָׁלוֹם, לכולם!", "مرحبًا، كيف حالكم؟"]);
});
