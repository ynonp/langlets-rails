// Model wiring. Same models as the Ruby concerns' MODEL_PARAMS:
//   extract_lyrics          gemini-3.5-flash          (Google, YouTube URL as a file part)
//   force_alignment         gemini-3.5-flash          (backup timing only, see below)
//   add_lessons             deepseek-v4-pro:cloud     (Ollama cloud)
//   rate_lessons            deepseek-v4-pro:cloud     (Ollama cloud)
//   add_token_translations  deepseek-v4-pro:cloud     (Ollama cloud)
//   translate               qwen3.5:397b-cloud        (Ollama cloud)
//
// extract_lyrics only gets the lyrics *text* from Gemini; word timing normally
// comes from ElevenLabs forced alignment (src/alignment.ts, ELEVEN_LABS_KEY),
// which is not an LLM and isn't wired here. The forceAlignment model is the
// fallback for when that path fails and Gemini has to time the lines itself.
//
// Ollama cloud speaks the OpenAI chat-completions dialect, so it goes through
// @ai-sdk/openai-compatible. Steps only ever see the LanguageModel interface,
// which is what lets tests swap in MockLanguageModelV2.

import { createGoogleGenerativeAI } from "@ai-sdk/google";
import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import type { LanguageModel } from "ai";
import { llmLoggingEnabled, withLlmLogging } from "./llmLogging.ts";

export interface ModelRegistry {
  extractLyrics: LanguageModel;
  forceAlignment: LanguageModel;
  addLessons: LanguageModel;
  rateLessons: LanguageModel;
  translate: LanguageModel;
  tokenTranslations: LanguageModel;
}

export interface ModelEnv {
  GOOGLE_GENERATIVE_AI_API_KEY?: string;
  OLLAMA_API_KEY?: string;
  OLLAMA_BASE_URL?: string;
  PIPELINE_LOG_LLM?: string;
}

export function defaultModels(env: ModelEnv = Deno.env.toObject()): ModelRegistry {
  const google = createGoogleGenerativeAI({ apiKey: env.GOOGLE_GENERATIVE_AI_API_KEY });
  const ollama = createOpenAICompatible({
    name: "ollama",
    baseURL: env.OLLAMA_BASE_URL ?? "https://ollama.com/v1",
    apiKey: env.OLLAMA_API_KEY,
  });

  // Full model outputs go to the console (PIPELINE_LOG_LLM=0 to silence).
  const log = llmLoggingEnabled(env)
    ? withLlmLogging
    : (model: LanguageModel, _label: string) => model;

  return {
    extractLyrics: log(google("gemini-3.5-flash"), "extract_lyrics"),
    forceAlignment: log(google("gemini-3.5-flash"), "force_alignment"),
    addLessons: log(ollama("deepseek-v4-pro:cloud"), "add_lessons"),
    rateLessons: log(ollama("deepseek-v4-pro:cloud"), "rate_lessons"),
    translate: log(ollama("qwen3.5:397b-cloud"), "translate"),
    tokenTranslations: log(ollama("deepseek-v4-pro:cloud"), "add_token_translations"),
  };
}
