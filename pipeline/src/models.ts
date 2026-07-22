// Model wiring. Same models as the Ruby concerns' MODEL_PARAMS:
//   extract_lyrics          Supadata native captions, then Gemini 2.5 Flash for YouTube
//   add_lessons             deepseek-v4-pro:cloud     (Ollama cloud)
//   rate_lessons            deepseek-v4-pro:cloud     (Ollama cloud)
//   add_token_translations  deepseek-v4-pro:cloud     (Ollama cloud)
//   translate               qwen3.5:397b-cloud        (Ollama cloud)
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
    extractLyrics: llmLoggingEnabled(env)
      ? withLlmLogging(google("gemini-2.5-flash"), "extract_lyrics", { logPrompt: true })
      : google("gemini-2.5-flash"),
    addLessons: log(google("gemini-3.5-flash-lite"), "add_lessons"),
    rateLessons: log(google("gemini-3.5-flash-lite"), "rate_lessons"),
    translate: log(ollama("qwen3.5:397b-cloud"), "translate"),
    tokenTranslations: log(google("gemini-3.5-flash-lite"), "add_token_translations"),
  };
}
