// yt-dlp audio download, used by forced alignment and by the TikTok
// speech-to-text fallback.
//
// One download attempt is not enough. TikTok serves silent HEVC renditions
// (`bytevc1` / `media-video-hvc1`) that yt-dlp does not flag as audio-less
// (yt-dlp#15642): the download "succeeds" and yields a file with either no
// audio stream at all or a stream of digital silence, and ElevenLabs then
// happily transcribes nothing. So a download only counts once ffprobe/ffmpeg
// confirm it carries audible audio; a file that fails that check is discarded
// and the next format spec is tried.

export interface DownloadedAudio {
  path: string;
  durationSeconds: number | null;
}

export interface AudioDownloadCommand {
  command: string;
  args: string[];
}

export interface AudioDownloadOptions {
  // yt-dlp `-f` spec.
  format?: string;
  // Post-process the download to mono 16 kHz m4a. Required for the fallback
  // specs, which select muxed video rather than an audio-only stream — both
  // ElevenLabs endpoints get audio bytes, and callers get the extension they
  // asked for.
  extractAudio?: boolean;
  // Linux network namespace to route the download through. Read from
  // YTDLP_NETWORK_NAMESPACE by downloadYoutubeAudioToTemp; omitted means yt-dlp
  // runs directly.
  networkNamespace?: string;
}

const NETWORK_NAMESPACE_PATTERN = /^[A-Za-z0-9_.-]+$/;

// yt-dlp prints these on stdout. They are tagged rather than bare because the
// duration and the final path are printed at different stages, so their order
// is not something to rely on.
const DURATION_TAG = "langlets_duration";
const FILEPATH_TAG = "langlets_filepath";

const DEFAULT_FORMAT = "bestaudio[ext=m4a]";

// Tried in order; the first one that yields audible audio wins.
//   1. the audio-only m4a that serves YouTube — unchanged from before, and the
//      only spec that needs no post-processing
//   2. any genuine audio-only stream the extractor exposes
//   3. the smallest muxed format that is neither silent HEVC nor audio-less
//   4. explicitly the H.264 rendition, which historically carries AAC
//   5. last resort: whatever yt-dlp would have picked by default
export const AUDIO_FORMATS: AudioDownloadOptions[] = [
  { format: DEFAULT_FORMAT },
  { format: "ba[acodec!=none]", extractAudio: true },
  { format: "worst[format_id!*=bytevc1][acodec!=none]", extractAudio: true },
  { format: "b[format_id*=h264]", extractAudio: true },
  { format: "b", extractAudio: true },
];

// Below this mean volume the track is digital silence in all but name.
const SILENCE_THRESHOLD_DB = -70;

export type AudioDefect = "no-audio-stream" | "silent";

export function audioDownloadCommand(
  youtubeUrl: string,
  outputPath: string,
  options: AudioDownloadOptions = {},
): AudioDownloadCommand {
  const args = [
    "--no-playlist",
    "--no-progress",
    "-f",
    options.format ?? DEFAULT_FORMAT,
    "-o",
    outputPath,
    "--force-overwrites",
    "--no-simulate",
    "--print",
    `${DURATION_TAG} %(duration)s`,
    "--print",
    `after_move:${FILEPATH_TAG} %(filepath)s`,
  ];
  if (options.extractAudio) {
    args.push(
      "-x",
      "--audio-format",
      "m4a",
      "--postprocessor-args",
      "ExtractAudio:-ac 1 -ar 16000",
    );
  }
  args.push(youtubeUrl);

  const namespace = options.networkNamespace;
  if (!namespace) return { command: "yt-dlp", args };
  if (!NETWORK_NAMESPACE_PATTERN.test(namespace)) {
    throw new Error(`Invalid YTDLP_NETWORK_NAMESPACE: ${namespace}`);
  }
  return { command: "ip", args: ["netns", "exec", namespace, "yt-dlp", ...args] };
}

export function audioStreamProbeCommand(audioPath: string): AudioDownloadCommand {
  return {
    command: "ffprobe",
    args: [
      "-v",
      "error",
      "-select_streams",
      "a:0",
      "-show_entries",
      "stream=codec_name",
      "-of",
      "csv=p=0",
      audioPath,
    ],
  };
}

export function meanVolumeProbeCommand(audioPath: string): AudioDownloadCommand {
  return {
    command: "ffmpeg",
    args: ["-hide_banner", "-nostats", "-i", audioPath, "-af", "volumedetect", "-f", "null", "-"],
  };
}

// volumedetect reports on stderr, once per input; the last reading is the one
// for this file.
export function parseMeanVolumeDb(output: string): number | null {
  const readings = [...output.matchAll(/mean_volume:\s*(-?[\d.]+) dB/g)];
  const last = readings.at(-1)?.[1];
  if (last === undefined) return null;
  const value = Number.parseFloat(last);
  return Number.isFinite(value) ? value : null;
}

export function parsePrintedValue(stdout: string, tag: string): string | null {
  const line = stdout
    .split("\n")
    .map((entry) => entry.trim())
    .reverse()
    .find((entry) => entry.startsWith(`${tag} `));
  const value = line?.slice(tag.length + 1).trim();
  // yt-dlp prints "NA" for fields the extractor did not supply.
  return value && value !== "NA" ? value : null;
}

// A track with no codec has no audio at all (the silent-HEVC case). A track
// whose mean volume cannot be read is one ffmpeg could not decode, which is as
// unusable as the silence it is grouped with.
export function classifyAudio(
  codec: string | null,
  meanVolumeDb: number | null,
): AudioDefect | null {
  if (!codec) return "no-audio-stream";
  if (meanVolumeDb === null || meanVolumeDb <= SILENCE_THRESHOLD_DB) return "silent";
  return null;
}

// Null means "usable as far as we can tell" — which includes the case where
// ffprobe/ffmpeg are not installed or not runnable. A missing verifier must not
// fail a download that would previously have been accepted.
export async function detectAudioDefect(audioPath: string): Promise<AudioDefect | null> {
  const stream = await runProbe(audioStreamProbeCommand(audioPath));
  if (!stream) return null;
  const codec = stream.code === 0 ? stream.stdout.trim() : "";
  if (!codec) return "no-audio-stream";

  const volume = await runProbe(meanVolumeProbeCommand(audioPath));
  if (!volume) return null;
  return classifyAudio(codec, parseMeanVolumeDb(volume.stderr));
}

export async function downloadYoutubeAudioToTemp(youtubeUrl: string): Promise<DownloadedAudio> {
  const path = await Deno.makeTempFile({ prefix: "langlets_audio_", suffix: ".m4a" });
  const networkNamespace = Deno.env.get("YTDLP_NETWORK_NAMESPACE") || undefined;
  const failures: string[] = [];

  try {
    for (const spec of AUDIO_FORMATS) {
      const attempt = await attemptDownload(youtubeUrl, path, { ...spec, networkNamespace });
      if (typeof attempt === "string") {
        failures.push(`${spec.format}: ${attempt}`);
      } else {
        const defect = await detectAudioDefect(path);
        if (!defect) return attempt;
        failures.push(`${spec.format}: ${defect}`);
      }
      console.warn(`Audio download rejected — ${failures.at(-1)}`);
      await Deno.remove(path).catch(() => {});
    }
    throw new Error(
      `yt-dlp produced no usable audio for ${youtubeUrl} (${failures.join("; ")})`,
    );
  } catch (error) {
    await Deno.remove(path).catch(() => {});
    throw error;
  }
}

// Resolves to the download on success, or to a one-line reason it is unusable —
// the loop above treats every reason the same way, so there is nothing to
// distinguish with an exception.
async function attemptDownload(
  youtubeUrl: string,
  path: string,
  options: AudioDownloadOptions,
): Promise<DownloadedAudio | string> {
  const spec = audioDownloadCommand(youtubeUrl, path, options);
  const result = await new Deno.Command(spec.command, {
    args: spec.args,
    stdout: "piped",
    stderr: "piped",
  }).output();
  const stdout = new TextDecoder().decode(result.stdout);
  if (result.code !== 0) {
    return `yt-dlp exited with code ${result.code}: ` +
      new TextDecoder().decode(result.stderr).trim();
  }

  // Post-processing can land the file beside the requested path under a
  // different extension. Move it back so callers have exactly one path to read
  // and one to delete.
  const produced = parsePrintedValue(stdout, FILEPATH_TAG);
  if (produced && produced !== path) await Deno.rename(produced, path);

  const size = await Deno.stat(path).then((info) => info.size).catch(() => 0);
  if (size === 0) return "yt-dlp wrote no audio bytes";

  const duration = Number.parseFloat(parsePrintedValue(stdout, DURATION_TAG) ?? "");
  return { path, durationSeconds: duration > 0 ? duration : null };
}

interface ProbeResult {
  code: number;
  stdout: string;
  stderr: string;
}

// Null when the tool cannot be run at all, as opposed to running and reporting
// something. Deployments that lack ffmpeg keep the pre-verification behavior.
async function runProbe(spec: AudioDownloadCommand): Promise<ProbeResult | null> {
  try {
    const result = await new Deno.Command(spec.command, {
      args: spec.args,
      stdout: "piped",
      stderr: "piped",
    }).output();
    const decoder = new TextDecoder();
    return {
      code: result.code,
      stdout: decoder.decode(result.stdout),
      stderr: decoder.decode(result.stderr),
    };
  } catch (error) {
    if (error instanceof Deno.errors.NotFound || error instanceof Deno.errors.PermissionDenied) {
      console.warn(`${spec.command} unavailable — skipping silent-audio verification`);
      return null;
    }
    throw error;
  }
}
