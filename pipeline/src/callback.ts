// Persistence lives only in the Rails postgres: every mutation the pipeline
// makes is shipped to the callback URL Rails passed with the trigger request,
// as a batch of PatchOps signed with the shared HMAC secret. If the callback
// can't be reached the run must abort — continuing would produce work nothing
// remembers.

import type { PatchOp, ProgressSink } from "./types.ts";
import { signedHeaders } from "./hmac.ts";

export class CallbackDeliveryError extends Error {}

export interface HttpCallbackOptions {
  maxRetries?: number;
  baseDelayMs?: number;
  fetchFn?: typeof fetch;
}

export class HttpCallbackClient implements ProgressSink {
  #url: string;
  #secret: string;
  #maxRetries: number;
  #baseDelayMs: number;
  #fetch: typeof fetch;

  constructor(url: string, secret: string, options: HttpCallbackOptions = {}) {
    this.#url = url;
    this.#secret = secret;
    this.#maxRetries = options.maxRetries ?? 3;
    this.#baseDelayMs = options.baseDelayMs ?? 1000;
    this.#fetch = options.fetchFn ?? fetch;
  }

  async patch(ops: PatchOp[]): Promise<void> {
    if (ops.length === 0) return;

    const body = JSON.stringify({ ops });
    let lastError: unknown;

    for (let attempt = 0; attempt <= this.#maxRetries; attempt++) {
      try {
        const response = await this.#fetch(this.#url, {
          method: "POST",
          headers: await signedHeaders(this.#secret, body),
          body,
        });
        if (response.ok) {
          await response.body?.cancel();
          return;
        }
        lastError = new CallbackDeliveryError(
          `callback responded ${response.status}: ${await response.text()}`,
        );
        // 4xx means Rails rejected the patch (bad signature, unknown record);
        // retrying the same body cannot succeed.
        if (response.status >= 400 && response.status < 500) break;
      } catch (error) {
        lastError = error;
      }

      if (attempt < this.#maxRetries) {
        await new Promise((r) => setTimeout(r, this.#baseDelayMs * 2 ** attempt));
      }
    }

    throw lastError instanceof Error
      ? lastError
      : new CallbackDeliveryError(String(lastError ?? "callback delivery failed"));
  }
}

// Test / dry-run sink: records every batch it receives.
export class MemorySink implements ProgressSink {
  batches: PatchOp[][] = [];

  get ops(): PatchOp[] {
    return this.batches.flat();
  }

  patch(ops: PatchOp[]): Promise<void> {
    this.batches.push(structuredClone(ops));
    return Promise.resolve();
  }
}
