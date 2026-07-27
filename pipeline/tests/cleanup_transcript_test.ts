import { assertEquals } from "@std/assert";
import { cleanupTranscript } from "../src/cleanupTranscript.ts";

Deno.test("cleanupTranscript removes non-speech annotations and musical notes", () => {
  assertEquals(
    cleanupTranscript("(footsteps) ♪ Hello [applause] (door squeaks) everyone ♪"),
    "Hello everyone",
  );
});

Deno.test("cleanupTranscript normalizes whitespace left by removed annotations", () => {
  assertEquals(cleanupTranscript("Hello\t(noise)\n  everyone"), "Hello everyone");
});
