import { assertEquals, assertFalse, assertRejects, assertThrows } from "@std/assert";
import {
  isSpeechToTextRequestRejected,
  parseSpeechToText,
  SpeechToTextRequestError,
  transcribeWithElevenLabs,
} from "../src/speechToText.ts";

// The payload shape ElevenLabs Scribe actually returns, trimmed to the fields
// the pipeline reads. Note the leading [cantando] audio_event and the spacing
// entries — the two things this parser exists to drop.
const SCRIBE_RESPONSE = {
  language_code: "spa",
  language_probability: 0.9868758916854858,
  text: "[cantando] Te doy las gracias, selección.",
  words: [
    { text: "[cantando]", start: 0.019, end: 0.359, type: "audio_event", logprob: -0.02 },
    { text: " ", start: 0.359, end: 0.5, type: "spacing", logprob: -0.009 },
    { text: "Te", start: 0.5, end: 0.68, type: "word", logprob: -0.009 },
    { text: " ", start: 0.68, end: 0.7, type: "spacing", logprob: -0.001 },
    { text: "doy", start: 0.7, end: 0.94, type: "word", logprob: -0.004 },
    { text: " ", start: 0.94, end: 0.96, type: "spacing", logprob: -0.001 },
    { text: "gracias,", start: 0.96, end: 1.4, type: "word", logprob: -0.006 },
  ],
};

Deno.test("keeps only timed speech words", () => {
  const result = parseSpeechToText(SCRIBE_RESPONSE);

  assertEquals(result.words.map((word) => word.text), ["Te", "doy", "gracias,"]);
  assertEquals(result.words[0], { text: "Te", start: 0.5, end: 0.68 });
  assertEquals(result.languageCode, "spa");
});

Deno.test("rebuilds the transcript from the kept words, not the response text", () => {
  // data.text still contains "[cantando]". Square brackets are reserved by the
  // app's token markup, and — more importantly — add_lessons partitions the
  // transcript by word count against these very words, so the two must agree.
  const result = parseSpeechToText(SCRIBE_RESPONSE);

  assertEquals(result.text, "Te doy gracias,");
  assertEquals(result.text.split(/\s+/).length, result.words.length);
});

Deno.test("drops words with missing or non-finite timestamps", () => {
  const result = parseSpeechToText({
    words: [
      { text: "kept", start: 1, end: 2, type: "word" },
      { text: "untimed", type: "word" },
      { text: "broken", start: 3, end: Number.NaN, type: "word" },
    ],
  });

  assertEquals(result.words.map((word) => word.text), ["kept"]);
});

Deno.test("a failed request carries its status, not just a message", async () => {
  const error = await assertRejects(
    () =>
      transcribeWithElevenLabs("https://www.tiktok.com/@a/video/1", "es", {
        apiKey: "test-key",
        fetch: () => Promise.resolve(new Response("could not download the file", { status: 400 })),
      }),
    SpeechToTextRequestError,
    "ElevenLabs speech-to-text failed (400)",
  );

  assertEquals(error.status, 400);
  // This is the signal extract_lyrics branches on to upload the audio instead.
  assertEquals(isSpeechToTextRequestRejected(error), true);
});

Deno.test("only a 400 counts as a rejected request", () => {
  assertFalse(isSpeechToTextRequestRejected(new SpeechToTextRequestError(500, "internal")));
  assertFalse(isSpeechToTextRequestRejected(new SpeechToTextRequestError(429, "slow down")));
  assertFalse(isSpeechToTextRequestRejected(new Error("ELEVEN_LABS_KEY is not set")));
});

Deno.test("a transcript with no speech is an error, not an empty course", () => {
  assertThrows(
    () =>
      parseSpeechToText({
        words: [{ text: "[Applause]", start: 0, end: 1, type: "audio_event" }],
      }),
    Error,
    "no timed words",
  );
});
