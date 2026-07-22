export interface DownloadedAudio {
  path: string;
  durationSeconds: number | null;
}

export interface AudioDownloadCommand {
  command: string;
  args: string[];
}

const NETWORK_NAMESPACE_PATTERN = /^[A-Za-z0-9_.-]+$/;

export function audioDownloadCommand(
  youtubeUrl: string,
  outputPath: string,
  networkNamespace = Deno.env.get("YTDLP_NETWORK_NAMESPACE"),
): AudioDownloadCommand {
  const args = [
    "--no-playlist",
    "--no-progress",
    "-f",
    "bestaudio[ext=m4a]",
    "-o",
    outputPath,
    "--force-overwrites",
    "--no-simulate",
    "--print",
    "duration",
    youtubeUrl,
  ];
  if (!networkNamespace) return { command: "yt-dlp", args };
  if (!NETWORK_NAMESPACE_PATTERN.test(networkNamespace)) {
    throw new Error(`Invalid YTDLP_NETWORK_NAMESPACE: ${networkNamespace}`);
  }
  return { command: "ip", args: ["netns", "exec", networkNamespace, "yt-dlp", ...args] };
}

export async function downloadYoutubeAudioToTemp(youtubeUrl: string): Promise<DownloadedAudio> {
  const path = await Deno.makeTempFile({ prefix: "langlets_audio_", suffix: ".m4a" });
  try {
    const spec = audioDownloadCommand(youtubeUrl, path);
    const result = await new Deno.Command(spec.command, {
      args: spec.args,
      stdout: "piped",
      stderr: "piped",
    }).output();
    if (result.code !== 0) {
      throw new Error(
        `yt-dlp exited with code ${result.code}: ${new TextDecoder().decode(result.stderr).trim()}`,
      );
    }
    const duration = Number.parseFloat(new TextDecoder().decode(result.stdout).trim());
    return { path, durationSeconds: duration > 0 ? duration : null };
  } catch (error) {
    await Deno.remove(path).catch(() => {});
    throw error;
  }
}
