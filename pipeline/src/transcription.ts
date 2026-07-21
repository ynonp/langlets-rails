// ElevenLabs speech-to-text fallback: when Gemini can't transcribe the clip
// (thinking budget eats the context window, video too long, etc.), download
// the audio and send it to ElevenLabs STT. The returned text is then fed into
// forced alignment as if Gemini had produced it.
//
// API: POST /v1/speech-to-text  (multipart/form-data)
// Model: scribe_v2

const BASE_URL = "https://api.elevenlabs.io";

export interface TranscriptionResult {
  text: string;
  language_code: string;
}

export async function transcribeWithElevenLabs(
  audioPath: string,
  languageCode: string | null,
  options: { apiKey?: string } = {},
): Promise<TranscriptionResult> {
  const apiKey = options.apiKey ?? Deno.env.get("ELEVEN_LABS_KEY");
  if (!apiKey) throw new Error("ELEVEN_LABS_KEY is not set");

  const bytes = await Deno.readFile(audioPath);
  const form = new FormData();
  form.append(
    "file",
    new Blob([bytes], { type: "audio/mp4" }),
    audioPath.split("/").at(-1) ?? "audio.m4a",
  );
  form.append("model_id", "scribe_v2");
  form.append("tag_audio_events", "false");
  form.append("timestamps_granularity", "none");
  if (languageCode) form.append("language_code", languageCode);

  const response = await fetch(`${BASE_URL}/v1/speech-to-text`, {
    method: "POST",
    headers: { "xi-api-key": apiKey },
    body: form,
  });
  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(`ElevenLabs STT failed (${response.status}): ${body}`);
  }

  const data = await response.json() as { text?: string; language_code?: string };
  const text = (data.text ?? "").trim();
  if (!text) throw new Error("ElevenLabs STT returned empty text");

  return { text, language_code: data.language_code ?? "unknown" };
}

// Split STT output into lyric lines. STT returns a continuous paragraph, but
// the pipeline expects one phrase per line (max ~42 chars). Break on sentence
// boundaries first, then on length.
export function sttTextToLines(text: string, maxChars = 42): string[] {
  // Split by sentence-ending punctuation followed by whitespace.
  const sentences = text.split(/(?<=[.!?])\s+/);
  const lines: string[] = [];

  for (const sentence of sentences) {
    const trimmed = sentence.trim();
    if (!trimmed) continue;

    if (trimmed.length <= maxChars) {
      lines.push(trimmed);
    } else {
      // Break long sentences at word boundaries.
      const words = trimmed.split(/\s+/);
      let current = "";
      for (const word of words) {
        const candidate = current ? `${current} ${word}` : word;
        if (candidate.length > maxChars && current) {
          lines.push(current);
          current = word;
        } else {
          current = candidate;
        }
      }
      if (current) lines.push(current);
    }
  }

  return lines.filter((l) => l !== "");
}

// Map English language names to ISO 639-1 codes for the STT language_code
// parameter. Same catalog as fuzzyword's ENGLISH_NAMES.
const LANGUAGE_TO_ISO: Record<string, string> = {
  english: "en",
  french: "fr",
  german: "de",
  hebrew: "he",
  russian: "ru",
  spanish: "es",
  arabic: "ar",
};

export function languageCodeForStt(
  clipLanguage: string,
  clipLanguageIso?: string | null,
): string | null {
  if (clipLanguageIso) return clipLanguageIso;
  return LANGUAGE_TO_ISO[clipLanguage.toLowerCase()] ?? null;
}
