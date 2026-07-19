// CLI runner: same pipeline, triggered from a terminal instead of HTTP.
//
//   deno task cli <callback_url> --input progress.json [--iso he] [--lang-id 3]
//
// `--input` is a CreateSongProgress export (the JSON written by
// CreateSongProgress#export: youtubeurl, clip_language, translation_language,
// data, ...) or a raw TriggerPayload. Patches are POSTed to <callback_url>
// signed with PIPELINE_HMAC_SECRET, exactly like the server flow. The export
// file names the translation language in English only, so pass --iso (and
// optionally --lang-id) when the export doesn't already carry a payload for
// the target language.

import { parseArgs } from "jsr:@std/cli@^1.0.0/parse-args";
import type { TriggerPayload } from "./src/types.ts";
import { defaultModels } from "./src/models.ts";
import { HttpCallbackClient } from "./src/callback.ts";
import { parseTriggerPayload, runPipeline } from "./src/pipeline.ts";

function usage(): never {
  console.error(
    "usage: deno task cli <callback_url> --input <progress.json> [--iso <code>] [--lang-id <id>]",
  );
  Deno.exit(1);
}

const args = parseArgs(Deno.args, {
  string: ["input", "iso", "lang-id"],
});

const callbackUrl = String(args._[0] ?? "");
if (!callbackUrl || !args.input) usage();

const secret = Deno.env.get("PIPELINE_HMAC_SECRET");
if (!secret) {
  console.error("PIPELINE_HMAC_SECRET is required");
  Deno.exit(1);
}

const raw = JSON.parse(await Deno.readTextFile(args.input));

// Accept either a raw TriggerPayload or a CreateSongProgress export.
let payload: TriggerPayload;
if (raw.callback_url || raw.translation_language?.iso_name) {
  payload = parseTriggerPayload({ ...raw, callback_url: callbackUrl });
} else {
  const iso = args.iso ??
    Object.keys(raw.data?.translations ?? {})[0];
  if (raw.translation_language && !iso) {
    console.error("export names its translation language in English only; pass --iso <code>");
    Deno.exit(1);
  }
  payload = parseTriggerPayload({
    youtubeurl: raw.youtubeurl,
    clip_language: raw.clip_language,
    translation_language: raw.translation_language
      ? {
        id: args["lang-id"] ? Number(args["lang-id"]) : null,
        iso_name: iso,
        english_name: raw.translation_language,
      }
      : null,
    callback_url: callbackUrl,
    data: raw.data ?? {},
  });
}

const sink = new HttpCallbackClient(callbackUrl, secret);
const result = await runPipeline(payload, { models: defaultModels(), sink });

console.log(JSON.stringify({ ok: result.ok, failed: result.failed, summary: result.summary }, null, 2));
Deno.exit(result.ok ? 0 : 1);
