import { assertEquals, assertThrows } from "@std/assert";
import {
  AUDIO_FORMATS,
  audioDownloadCommand,
  audioStreamProbeCommand,
  classifyAudio,
  meanVolumeProbeCommand,
  parseMeanVolumeDb,
  parsePrintedValue,
} from "../src/audio.ts";

const youtubeUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";
const outputPath = "/tmp/audio.m4a";

Deno.test("audio download runs yt-dlp directly by default", () => {
  const command = audioDownloadCommand(youtubeUrl, outputPath);
  assertEquals(command.command, "yt-dlp");
  assertEquals(command.args.at(-1), youtubeUrl);
  assertEquals(command.args.includes(outputPath), true);
  assertEquals(command.args.includes("bestaudio[ext=m4a]"), true);
});

Deno.test("audio download supports a network namespace", () => {
  const command = audioDownloadCommand(youtubeUrl, outputPath, { networkNamespace: "vpn" });
  assertEquals(command.command, "ip");
  assertEquals(command.args.slice(0, 4), ["netns", "exec", "vpn", "yt-dlp"]);
});

Deno.test("audio download rejects unsafe namespace names", () => {
  assertThrows(
    () => audioDownloadCommand(youtubeUrl, outputPath, { networkNamespace: "vpn namespace" }),
    Error,
    "Invalid YTDLP_NETWORK_NAMESPACE",
  );
});

Deno.test("the default format needs no post-processing", () => {
  const command = audioDownloadCommand(youtubeUrl, outputPath);
  assertEquals(command.args.includes("-x"), false);
});

Deno.test("fallback formats are extracted to mono 16 kHz m4a", () => {
  const command = audioDownloadCommand(youtubeUrl, outputPath, {
    format: "b",
    extractAudio: true,
  });
  assertEquals(command.args.includes("-x"), true);
  assertEquals(command.args[command.args.indexOf("--audio-format") + 1], "m4a");
  assertEquals(
    command.args[command.args.indexOf("--postprocessor-args") + 1],
    "ExtractAudio:-ac 1 -ar 16000",
  );
});

Deno.test("the format ladder starts audio-only and ends with yt-dlp's own pick", () => {
  assertEquals(AUDIO_FORMATS[0], { format: "bestaudio[ext=m4a]" });
  assertEquals(AUDIO_FORMATS.at(-1)?.format, "b");
  // Every spec after the first selects muxed video and therefore must extract.
  assertEquals(AUDIO_FORMATS.slice(1).every((spec) => spec.extractAudio), true);
  // The silent HEVC rendition yt-dlp does not flag (yt-dlp#15642) is excluded
  // explicitly, so it is never the format that "succeeds".
  assertEquals(AUDIO_FORMATS.some((spec) => spec.format?.includes("format_id!*=bytevc1")), true);
});

Deno.test("printed values are read by tag, not by line position", () => {
  const stdout = [
    "[youtube] Extracting URL",
    "langlets_duration 212.0",
    "langlets_filepath /tmp/langlets_audio_abc.m4a",
  ].join("\n");

  assertEquals(parsePrintedValue(stdout, "langlets_duration"), "212.0");
  assertEquals(parsePrintedValue(stdout, "langlets_filepath"), "/tmp/langlets_audio_abc.m4a");
  assertEquals(parsePrintedValue(stdout, "langlets_missing"), null);
});

Deno.test("a printed NA reads as absent", () => {
  assertEquals(parsePrintedValue("langlets_duration NA", "langlets_duration"), null);
});

Deno.test("mean volume comes from the last volumedetect reading", () => {
  const stderr = [
    "[Parsed_volumedetect_0 @ 0x1] mean_volume: -91.0 dB",
    "[Parsed_volumedetect_0 @ 0x1] max_volume: -91.0 dB",
    "[Parsed_volumedetect_0 @ 0x2] mean_volume: -18.4 dB",
  ].join("\n");

  assertEquals(parseMeanVolumeDb(stderr), -18.4);
});

Deno.test("no volumedetect reading is not a volume of zero", () => {
  assertEquals(parseMeanVolumeDb("ffmpeg version 8.1.1\nOutput file is empty"), null);
});

Deno.test("a download with no audio stream is rejected", () => {
  assertEquals(classifyAudio(null, null), "no-audio-stream");
  assertEquals(classifyAudio("", -20), "no-audio-stream");
});

Deno.test("a present but silent track is rejected, an audible one is kept", () => {
  // The TikTok failure this exists for: an AAC stream that decodes to nothing.
  assertEquals(classifyAudio("aac", -91), "silent");
  assertEquals(classifyAudio("aac", -70), "silent");
  assertEquals(classifyAudio("aac", -18.4), null);
});

Deno.test("an undecodable track counts as silent rather than usable", () => {
  assertEquals(classifyAudio("aac", null), "silent");
});

Deno.test("probes ask ffprobe for the first audio stream's codec", () => {
  const probe = audioStreamProbeCommand(outputPath);
  assertEquals(probe.command, "ffprobe");
  assertEquals(probe.args.includes("a:0"), true);
  assertEquals(probe.args.at(-1), outputPath);
});

Deno.test("volume probe decodes to null so nothing is written", () => {
  const probe = meanVolumeProbeCommand(outputPath);
  assertEquals(probe.command, "ffmpeg");
  assertEquals(probe.args.slice(-4), ["volumedetect", "-f", "null", "-"]);
});
