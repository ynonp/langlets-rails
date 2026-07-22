import { assertEquals, assertRejects } from "@std/assert";
import { MAX_LINE_LENGTH, transcribeWithSupadata, transcriptToLines } from "../src/supadata.ts";

Deno.test("Supadata client sends a generated timestamped transcript request", async () => {
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
  assertEquals(requested!.searchParams.get("mode"), "generate");
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
