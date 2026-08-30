import { assertEquals, assertThrows } from "@std/assert";
import { detectLanguage, resolveLanguage } from "../src/languageDetection.ts";
import { queuedModel, STUB_AUDIO_PATH } from "./helpers.ts";

const LANGUAGES = [
  { iso_name: "en", english_name: "English" },
  { iso_name: "es", english_name: "Spanish" },
  { iso_name: "ar-JO", english_name: "Arabic" },
  { iso_name: "de", english_name: "German" },
  { iso_name: "fr", english_name: "French" },
  { iso_name: "he", english_name: "Hebrew" },
  { iso_name: "el", english_name: "Greek" },
  { iso_name: "sv", english_name: "Swedish" },
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

Deno.test("TikTok falls back to ElevenLabs URL fetch when yt-dlp cannot produce audio", async () => {
  let fetchedUrl: string | undefined;
  const result = await detectLanguage(
    {
      youtubeurl: "https://www.tiktok.com/@scout/video/6718335390845095173",
      supported_languages: LANGUAGES,
    },
    {
      model: queuedModel([]).model,
      prepareAudio: () => Promise.reject(new Error("all formats failed")),
      transcribeUrl: (url, languageCode) => {
        fetchedUrl = url;
        assertEquals(languageCode, null);
        return Promise.resolve({
          text: "שלום",
          words: [{ text: "שלום", start: 0, end: 0.5 }],
          languageCode: "heb",
          languageProbability: 0.99,
        });
      },
    },
  );

  assertEquals(fetchedUrl, "https://www.tiktok.com/@scout/video/6718335390845095173");
  assertEquals(result.language, LANGUAGES[5]);
  assertEquals(result.data, {
    stt_candidates: {
      elevenlabs: {
        text: "שלום",
        words: [{ text: "שלום", start: 0, end: 0.5 }],
      },
    },
  });
});

Deno.test("Scribe ISO-639-3 codes map to the Langlets language catalog", () => {
  const expected = ["eng", "spa", "ara", "deu", "fra", "heb", "ell", "swe"];
  expected.forEach((code, index) =>
    assertEquals(resolveLanguage(code, LANGUAGES), LANGUAGES[index])
  );

  assertEquals(resolveLanguage("gre", LANGUAGES), LANGUAGES[6]);

  assertThrows(
    () => resolveLanguage("ita", LANGUAGES),
    Error,
    "detected unsupported language",
  );
});
