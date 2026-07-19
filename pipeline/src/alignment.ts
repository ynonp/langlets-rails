// ElevenLabs forced alignment: given a local audio file and the known lyrics
// text, returns start/end timestamps (float seconds) for every word of that
// text. Unlike speech-to-text, the words are taken as ground truth — the model
// only has to locate them in the audio, which is far more reliable on sung
// vocals.

const BASE_URL = "https://api.elevenlabs.io";

export interface AlignedWord {
  text: string;
  // Seconds from the start of the audio.
  start: number;
  end: number;
  // Per-word alignment loss (lower is better).
  loss?: number;
}

export interface Alignment {
  words: AlignedWord[];
  // Overall alignment loss for the file.
  loss: number | null;
}

export async function alignLyrics(
  audioPath: string,
  text: string,
  options: { apiKey?: string } = {},
): Promise<Alignment> {
  const apiKey = options.apiKey ?? Deno.env.get("ELEVEN_LABS_KEY");
  if (!apiKey) throw new Error("ELEVEN_LABS_KEY is not set");

  const bytes = await Deno.readFile(audioPath);
  const form = new FormData();
  form.append(
    "file",
    new Blob([bytes], { type: "audio/mp4" }),
    audioPath.split("/").at(-1) ?? "audio.m4a",
  );
  form.append("text", text);

  const response = await fetch(`${BASE_URL}/v1/forced-alignment`, {
    method: "POST",
    headers: { "xi-api-key": apiKey },
    body: form,
  });
  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(`ElevenLabs forced alignment failed (${response.status}): ${body}`);
  }

  const data = await response.json() as { words?: AlignedWord[]; loss?: number };
  return {
    words: (data.words ?? [])
      .filter((w) => w.text.trim() !== "")
      .map((w) => ({ text: w.text, start: w.start, end: w.end, loss: w.loss })),
    loss: typeof data.loss === "number" ? data.loss : null,
  };
}
