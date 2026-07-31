import { assert, assertEquals } from "@std/assert";
import { createHandler } from "../src/server.ts";
import { signedHeaders } from "../src/hmac.ts";
import type { ModelRegistry } from "../src/models.ts";
import type { TriggerPayload } from "../src/types.ts";
import type { RunResult } from "../src/pipeline.ts";
import { unusedModel } from "./helpers.ts";

const SECRET = "server-secret";

function models(): ModelRegistry {
  return {
    detectLanguage: unusedModel().model,
    extractLyrics: unusedModel().model,
    forceAlignmentFallback: unusedModel().model,
    addLessons: unusedModel().model,
    rateLessons: unusedModel().model,
    translate: unusedModel().model,
    tokenTranslations: unusedModel().model,
  };
}

function okResult(): RunResult {
  return { ok: true, failed: {}, data: {}, summary: { phrases: 2 } };
}

function triggerBody(): string {
  return JSON.stringify({
    youtubeurl: "https://www.youtube.com/watch?v=abc",
    clip_language: "French",
    translation_language: { id: 3, iso_name: "he", english_name: "Hebrew" },
    callback_url: "https://rails.example/cb",
    data: {},
  });
}

async function signedPost(body: string, secret = SECRET, path = "/run"): Promise<Request> {
  return new Request(`https://pipeline.example${path}`, {
    method: "POST",
    headers: await signedHeaders(secret, body),
    body,
  });
}

Deno.test("health endpoint responds without a signature", async () => {
  const handler = createHandler({ secret: SECRET, models: models() });
  const response = await handler(new Request("https://pipeline.example/health"));
  assertEquals(response.status, 200);
});

Deno.test("unknown paths 404", async () => {
  const handler = createHandler({ secret: SECRET, models: models() });
  const response = await handler(await signedPost(triggerBody(), SECRET, "/other"));
  assertEquals(response.status, 404);
});

Deno.test("unsigned trigger is rejected", async () => {
  const handler = createHandler({ secret: SECRET, models: models() });
  const response = await handler(
    new Request("https://pipeline.example/run", { method: "POST", body: triggerBody() }),
  );
  assertEquals(response.status, 401);
});

Deno.test("trigger signed with the wrong secret is rejected", async () => {
  const handler = createHandler({ secret: SECRET, models: models() });
  const response = await handler(await signedPost(triggerBody(), "wrong-secret"));
  assertEquals(response.status, 401);
});

Deno.test("a valid trigger runs the pipeline and reports the outcome", async () => {
  let received: TriggerPayload | null = null;
  const handler = createHandler({
    secret: SECRET,
    models: models(),
    run: (payload) => {
      received = payload;
      return Promise.resolve(okResult());
    },
  });

  const response = await handler(await signedPost(triggerBody()));
  assertEquals(response.status, 200);

  const body = await response.json();
  assertEquals(body.ok, true);
  assertEquals(body.summary.phrases, 2);
  assertEquals(received!.clip_language, "French");
  assertEquals(received!.translation_language!.iso_name, "he");
  assertEquals(received!.callback_url, "https://rails.example/cb");
});

Deno.test("step failures surface as a 500 with the failed branches", async () => {
  const handler = createHandler({
    secret: SECRET,
    models: models(),
    run: () =>
      Promise.resolve({
        ok: false,
        failed: { translate: "line count doesnt match" },
        data: {},
        summary: {},
      }),
  });

  const response = await handler(await signedPost(triggerBody()));
  assertEquals(response.status, 500);
  const body = await response.json();
  assertEquals(body.failed.translate, "line count doesnt match");
});

Deno.test("async mode responds 202 before the run finishes", async () => {
  let resolveRun: (r: RunResult) => void = () => {};
  let finished = false;
  const running = new Promise<RunResult>((resolve) => {
    resolveRun = (r) => {
      finished = true;
      resolve(r);
    };
  });

  const handler = createHandler({
    secret: SECRET,
    models: models(),
    run: () => running,
  });

  const response = await handler(await signedPost(triggerBody(), SECRET, "/run?async=1"));
  assertEquals(response.status, 202);
  assert(!finished);
  resolveRun(okResult());
  await running;
});

Deno.test("malformed payloads are a 422, not a crash", async () => {
  const handler = createHandler({ secret: SECRET, models: models() });

  const missingUrl = JSON.stringify({ clip_language: "French", callback_url: "https://x" });
  const response = await handler(await signedPost(missingUrl));
  assertEquals(response.status, 422);
  const body = await response.json();
  assert(body.error.includes("youtubeurl"));
});
