// Deno Deploy / local server entrypoint.
//
//   PIPELINE_HMAC_SECRET          shared secret for trigger + callback signing
//   GOOGLE_GENERATIVE_AI_API_KEY  Gemini (extract_lyrics)
//   OLLAMA_API_KEY                Ollama cloud (all other steps)
//   OLLAMA_BASE_URL               optional, defaults to https://ollama.com/v1
//
// Local: deno task serve

import { createHandler } from "./src/server.ts";
import { defaultModels } from "./src/models.ts";

const secret = Deno.env.get("PIPELINE_HMAC_SECRET");
if (!secret) {
  console.error("PIPELINE_HMAC_SECRET is required");
  Deno.exit(1);
}

Deno.serve(createHandler({ secret, models: defaultModels() }));
