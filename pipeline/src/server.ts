// HTTP trigger for the pipeline (the entry Deno Deploy serves via main.ts).
//
//   POST /run          run the pipeline, respond when it finishes
//   POST /run?async=1  respond 202 immediately, keep running in the background
//   GET  /health       liveness probe (unsigned)
//
// Every POST body must carry the HMAC headers (see hmac.ts); the same secret
// signs the callbacks the run sends back. The async form fits the
// worker-triggered flow — Rails learns about progress through the callback,
// and a dropped run is recovered by simply triggering again with the saved
// data. Note that on serverless platforms background work may be cut short
// when the isolate shuts down; that is acceptable for the same reason.

import type { TriggerPayload } from "./types.ts";
import { verifyRequest } from "./hmac.ts";
import { HttpCallbackClient } from "./callback.ts";
import { parseTriggerPayload, runPipeline, type RunResult } from "./pipeline.ts";
import type { ModelRegistry } from "./models.ts";
import { message } from "./retry.ts";

export interface ServerOptions {
  secret: string;
  models: ModelRegistry;
  baseDelayMs?: number;
  // Overridable for tests.
  run?: (payload: TriggerPayload, options: {
    models: ModelRegistry;
    sink: HttpCallbackClient;
    baseDelayMs?: number;
  }) => Promise<RunResult>;
}

export function createHandler(options: ServerOptions): (request: Request) => Promise<Response> {
  const run = options.run ?? runPipeline;

  return async (request: Request): Promise<Response> => {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return json(200, { ok: true });
    }

    if (request.method !== "POST" || url.pathname !== "/run") {
      return json(404, { error: "not found" });
    }

    const body = await verifyRequest(options.secret, request);
    if (body === null) return json(401, { error: "invalid signature" });

    let payload: TriggerPayload;
    try {
      payload = parseTriggerPayload(JSON.parse(body));
    } catch (error) {
      return json(422, { error: message(error) });
    }

    const sink = new HttpCallbackClient(payload.callback_url, options.secret);
    const execution = run(payload, {
      models: options.models,
      sink,
      baseDelayMs: options.baseDelayMs,
    });

    if (url.searchParams.get("async") === "1") {
      execution.catch((error) => console.error(`pipeline run failed: ${message(error)}`));
      return json(202, { accepted: true });
    }

    try {
      const result = await execution;
      return json(result.ok ? 200 : 500, {
        ok: result.ok,
        failed: result.failed,
        summary: result.summary,
      });
    } catch (error) {
      // runPipeline reports step failures in its result; reaching here means
      // something outside the steps broke (e.g. callback delivery).
      return json(500, { ok: false, error: message(error) });
    }
  };
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
