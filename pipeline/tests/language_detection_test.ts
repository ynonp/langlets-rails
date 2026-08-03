import { assertEquals, assertThrows } from "@std/assert";
import { detectLanguage, resolveLanguage } from "../src/languageDetection.ts";
import { queuedModel, STUB_AUDIO_PATH } from "./helpers.ts";

const LANGUAGES = [
  { iso_name: "en", english_name: "English" },
  { iso_name: "es", english_name: "Spanish" },
  { iso_name: "ar-JO", english_name: "Arabic" },
];

Deno.test("YouTube language detection uses Gemini and resolves a seeded language", async () => {
  const gemini = queuedModel(["es\n"]);
  const result = await detectLanguage(
    {
      youtubeurl: "https://www.youtube.com/watch?v=kJQP7kiw5Fk",
      supported_languages: LANGUAGES,
    },
    { model: gemini.model },
  );

  assertEquals(result.language, LANGUAGES[1]);
  assertEquals(result.data, {});
  assertEquals(gemini.calls(), 1);
});

Deno.test("TikTok downloads audio and reuses ElevenLabs detected transcript", async () => {
  const result = await detectLanguage(
    {
      youtubeurl: "https://www.tiktok.com/@scout/video/6718335390845095173",
      supported_languages: LANGUAGES,
    },
    {
      model: queuedModel([]).model,
      prepareAudio: () => Promise.resolve({ path: STUB_AUDIO_PATH, durationSeconds: 3 }),
      transcribeFile: (_path, languageCode) => {
        assertEquals(languageCode, null);
        return Promise.resolve({
          text: "hola",
          words: [{ text: "hola", start: 0, end: 0.5 }],
          languageCode: "spa",
          languageProbability: 0.99,
        });
      },
    },
  );

  assertEquals(result.language, LANGUAGES[1]);
  assertEquals(result.data, {
    stt_candidates: {
      elevenlabs: {
        text: "hola",
        words: [{ text: "hola", start: 0, end: 0.5 }],
      },
    },
  });
});

Deno.test("regional seeded codes match detected base codes and unsupported codes fail", () => {
  assertEquals(resolveLanguage("ara", LANGUAGES), LANGUAGES[2]);
  assertThrows(
    () => resolveLanguage("ita", LANGUAGES),
    Error,
    "detected unsupported language",
  );
});
