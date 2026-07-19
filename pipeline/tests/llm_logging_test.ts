import { assert, assertEquals } from "@std/assert";
import { generateText } from "ai";
import { llmLoggingEnabled, sliceText, withLlmLogging } from "../src/llmLogging.ts";
import { queuedModel } from "./helpers.ts";

function captureLogs<T>(fn: () => Promise<T>): Promise<{ result: T; lines: string[] }> {
  const lines: string[] = [];
  const original = console.log;
  console.log = (...args: unknown[]) => lines.push(args.join(" "));
  return fn()
    .then((result) => ({ result, lines }))
    .finally(() => (console.log = original));
}

Deno.test("llmLoggingEnabled is on by default and off for 0/false", () => {
  assert(llmLoggingEnabled({}));
  assert(llmLoggingEnabled({ PIPELINE_LOG_LLM: "1" }));
  assert(!llmLoggingEnabled({ PIPELINE_LOG_LLM: "0" }));
  assert(!llmLoggingEnabled({ PIPELINE_LOG_LLM: "false" }));
});

Deno.test("sliceText splits long output into cap-sized slices", () => {
  assertEquals(sliceText("short", 10), ["short"]);
  const slices = sliceText("a".repeat(25), 10);
  assertEquals(slices.map((s) => s.length), [10, 10, 5]);
  assertEquals(slices.join(""), "a".repeat(25));
});

Deno.test("wrapped model logs the full output and passes the result through", async () => {
  const inner = queuedModel(["the full LLM output"]);
  const model = withLlmLogging(inner.model, "translate");

  const { result, lines } = await captureLogs(() => generateText({ model, prompt: "hi" }));

  assertEquals(result.text, "the full LLM output");
  assertEquals(lines.length, 1);
  assert(lines[0].startsWith("[llm translate mock-model]"));
  assert(lines[0].includes("the full LLM output"));
});

Deno.test("long outputs are logged in numbered slices, none oversized", async () => {
  const long = "x".repeat(4000);
  const inner = queuedModel([long]);
  const model = withLlmLogging(inner.model, "extract_lyrics");

  const { lines } = await captureLogs(() => generateText({ model, prompt: "hi" }));

  assertEquals(lines.length, 3);
  assert(lines[0].includes("1/3"));
  assert(lines[2].includes("3/3"));
  for (const line of lines) assert(line.length < 2000);
  assertEquals(lines.map((l) => l.split("\n")[1]).join(""), long);
});

Deno.test("a failing call still logs a marker and rethrows", async () => {
  const inner = queuedModel([]); // exhausted: doGenerate throws
  const model = withLlmLogging(inner.model, "rate_lessons");

  let threw = false;
  const { lines } = await captureLogs(async () => {
    try {
      await generateText({ model, prompt: "hi" });
    } catch {
      threw = true;
    }
  });

  assert(threw);
  assertEquals(lines.length, 1);
  assert(lines[0].includes("<call failed:"));
});
