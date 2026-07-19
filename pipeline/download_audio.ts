// Standalone CLI: download the audio track of a YouTube video to an m4a file.
//
//   deno task download <url-or-video-id> [output.m4a]
//
// Defaults the output filename to <videoId>.m4a. Uses the same downloader as
// the pipeline's extract_lyrics step (src/audio.ts), which shells out to the
// yt-dlp binary — it must be installed and on PATH.

import { downloadYoutubeAudio, getVideoId } from "./src/audio.ts";

const input = Deno.args[0];

if (!input) {
  console.error("Usage: deno task download <url-or-video-id> [output.m4a]");
  Deno.exit(1);
}

const output = Deno.args[1] ?? `${getVideoId(input)}.m4a`;

await downloadYoutubeAudio(input, output);

const { size } = await Deno.stat(output);
console.log(`Saved: ${output} (${(size / 1024 / 1024).toFixed(1)} MB)`);
