const BASE_URL = "https://api.elevenlabs.io";

export interface AlignedWord {
  text: string;
  start: number;
  end: number;
  loss?: number;
}

export interface Alignment {
  words: AlignedWord[];
  loss: number | null;
}

export async function alignLyrics(
  audioPath: string,
  text: string,
  options: { apiKey?: string; fetch?: typeof globalThis.fetch } = {},
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

  const response = await (options.fetch ?? globalThis.fetch)(`${BASE_URL}/v1/forced-alignment`, {
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
    words: (data.words ?? []).filter((word) => word.text.trim() !== ""),
    loss: typeof data.loss === "number" ? data.loss : null,
  };
}
