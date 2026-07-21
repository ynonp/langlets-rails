// Console logging of full LLM outputs, as a model middleware so every step is
// covered from one place (the role TracedChat played in the Ruby pipeline).
//
// Deno Deploy truncates long log lines, and a transcription turn or a
// 200-word translation chunk easily exceeds the limit — so the output is
// printed in numbered slices small enough to survive intact, all sharing one
// label so they can be grepped back together in the log view.
//
// On by default; set PIPELINE_LOG_LLM=0 to silence.

import { type LanguageModel, wrapLanguageModel } from "ai";

// Comfortably under Deploy's per-line cap.
const SLICE_CHARS = 1800;

export function llmLoggingEnabled(env: { PIPELINE_LOG_LLM?: string }): boolean {
  return !["0", "false"].includes((env.PIPELINE_LOG_LLM ?? "").toLowerCase());
}

// deno-lint-ignore no-explicit-any
type GenerateResult = { content?: Array<any> };

export interface LlmLoggingOptions {
  logPrompt?: boolean;
}

export function withLlmLogging(
  model: LanguageModel,
  label: string,
  options: LlmLoggingOptions = {},
): LanguageModel {
  if (typeof model === "string") return model;

  return wrapLanguageModel({
    model,
    middleware: {
      wrapGenerate: async ({ doGenerate, params }) => {
        if (options.logPrompt) {
          logOutput(label, model.modelId, JSON.stringify(params.prompt, null, 2), "prompt");
        }
        try {
          const result = await doGenerate();
          logOutput(label, model.modelId, outputText(result), "response");
          return result;
        } catch (error) {
          logOutput(label, model.modelId, `<call failed: ${error}>`, "response");
          throw error;
        }
      },
    },
  });
}

function outputText(result: GenerateResult): string {
  const parts = result.content ?? [];
  const text = parts
    .filter((p) => p?.type === "text")
    .map((p) => p.text)
    .join("");
  if (text !== "") return text;

  // No text parts (tool calls, empty response, ...): show what came back.
  return `<no text content: ${JSON.stringify(parts.map((p) => p?.type))}>`;
}

export function logOutput(
  label: string,
  modelId: string,
  text: string,
  direction?: "prompt" | "response",
): void {
  const slices = sliceText(text, SLICE_CHARS);
  slices.forEach((slice, i) => {
    const part = slices.length > 1 ? ` ${i + 1}/${slices.length}` : "";
    const kind = direction ? ` ${direction}` : "";
    console.log(`[llm ${label} ${modelId}${kind}${part}]\n${slice}`);
  });
}

export function sliceText(text: string, size: number): string[] {
  if (text.length <= size) return [text];

  const slices: string[] = [];
  for (let at = 0; at < text.length; at += size) {
    slices.push(text.slice(at, at + size));
  }
  return slices;
}
