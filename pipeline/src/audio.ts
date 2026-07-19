// Audio sourcing for the alignment step: download the clip's audio track from
// YouTube via the yt-dlp binary (which must be on PATH). The lyrics call
// doesn't need this — Gemini reads the YouTube URL directly as a file part —
// only ElevenLabs forced alignment needs the actual bytes.

export interface DownloadedAudio {
  // Local m4a file; the caller is responsible for removing it.
  path: string;
  // Clip duration as reported by yt-dlp, for coverage checks and progress
  // reporting. Null when yt-dlp doesn't report one.
  durationSeconds: number | null;
}

export function getVideoId(input: string): string {
  if (/^[\w-]{11}$/.test(input)) return input;

  const url = new URL(input);

  if (url.hostname === "youtu.be") return url.pathname.split("/")[1];

  const queryId = url.searchParams.get("v");
  if (queryId) return queryId;

  const match = url.pathname.match(/^\/(?:shorts|embed|live)\/([\w-]{11})/);
  if (match) return match[1];

  throw new Error(`Invalid YouTube URL: ${input}`);
}

// Download the audio track to outputPath and return the clip duration in
// seconds (null when unavailable).
export async function downloadYoutubeAudio(
  youtubeUrl: string,
  outputPath: string,
): Promise<number | null> {
  const command = new Deno.Command("yt-dlp", {
    args: [
      "--no-playlist",
      "--no-progress",
      // m4a only (itag 140, always available on YouTube) — a single container
      // format keeps the uploaded bytes predictable.
      "-f",
      "bestaudio[ext=m4a]",
      "-o",
      outputPath,
      "--force-overwrites",
      // --print implies --simulate, so --no-simulate keeps the download while
      // still printing the clip duration to stdout.
      "--no-simulate",
      "--print",
      "duration",
      youtubeUrl,
    ],
    stdout: "piped",
    stderr: "piped",
  });

  const { code, stdout, stderr } = await command.output();
  if (code !== 0) {
    throw new Error(`yt-dlp exited with code ${code}: ${new TextDecoder().decode(stderr).trim()}`);
  }

  const duration = parseFloat(new TextDecoder().decode(stdout).trim());
  return Number.isFinite(duration) && duration > 0 ? duration : null;
}

export async function downloadYoutubeAudioToTemp(youtubeUrl: string): Promise<DownloadedAudio> {
  const tempPath = await Deno.makeTempFile({ prefix: "langlets_audio_", suffix: ".m4a" });
  try {
    const durationSeconds = await downloadYoutubeAudio(youtubeUrl, tempPath);
    return { path: tempPath, durationSeconds };
  } catch (error) {
    await Deno.remove(tempPath).catch(() => {});
    throw error;
  }
}
