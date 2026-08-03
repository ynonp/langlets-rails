// Deno Deploy / local server entrypoint.
//
//   PIPELINE_HMAC_SECRET          shared secret for trigger + callback signing
//   SUPADATA_KEY                  Supadata native transcription
//   ELEVEN_LABS_KEY               ElevenLabs transcription + word timing
//   OPENAI_API_KEY                GPT-5.6 Sol transcript reconciliation
//   GOOGLE_GENERATIVE_AI_API_KEY  Gemini (lesson and token work)
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
