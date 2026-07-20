import { assertEquals, assertThrows } from "@std/assert";
import { audioDownloadCommand } from "../src/audio.ts";

const youtubeUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";
const outputPath = "/tmp/audio.m4a";

Deno.test("audio download runs yt-dlp directly when no namespace is configured", () => {
  const command = audioDownloadCommand(youtubeUrl, outputPath, undefined);

  assertEquals(command.command, "yt-dlp");
  assertEquals(command.args.at(-1), youtubeUrl);
  assertEquals(command.args.includes(outputPath), true);
});

Deno.test("audio download runs yt-dlp in the configured network namespace", () => {
  const command = audioDownloadCommand(youtubeUrl, outputPath, "vpn");

  assertEquals(command.command, "ip");
  assertEquals(command.args.slice(0, 4), ["netns", "exec", "vpn", "yt-dlp"]);
  assertEquals(command.args.at(-1), youtubeUrl);
});

Deno.test("audio download rejects an invalid network namespace", () => {
  assertThrows(
    () => audioDownloadCommand(youtubeUrl, outputPath, "vpn namespace"),
    Error,
    "Invalid YTDLP_NETWORK_NAMESPACE",
  );
});
