import { assertEquals, assertRejects } from "@std/assert";
import { MAX_VIDEO_SECONDS, validateVideoDuration } from "../src/videoDuration.ts";

const VIDEO = "https://www.youtube.com/watch?v=test123";

function metadata(duration: unknown): typeof fetch {
  return async (input, init) => {
    const url = new URL(String(input));
    assertEquals(url.pathname, "/v1/metadata");
    assertEquals(url.searchParams.get("url"), VIDEO);
    assertEquals(new Headers(init?.headers).get("x-api-key"), "test-key");
    return Response.json({ media: { duration } });
  };
}

Deno.test("reads the current top-level duration response", async () => {
  const fetch: typeof globalThis.fetch = async () => Response.json({ duration: 123 });
  await validateVideoDuration(VIDEO, { apiKey: "test-key", fetch });
});

Deno.test("accepts short videos and the exact duration limit", async () => {
  for (const duration of [1, MAX_VIDEO_SECONDS - 1, MAX_VIDEO_SECONDS]) {
    await validateVideoDuration(VIDEO, { apiKey: "test-key", fetch: metadata(duration) });
  }
});

Deno.test("rejects videos even a fraction of a second over the limit", async () => {
  await assertRejects(
    () =>
      validateVideoDuration(VIDEO, {
        apiKey: "test-key",
        fetch: metadata(MAX_VIDEO_SECONDS + 0.1),
      }),
    Error,
    "Please choose a video that is 20 minutes or shorter.",
  );
});

Deno.test("continues unchecked when duration is missing or unusable", async () => {
  for (const duration of [undefined, null, 0, -1, "1201", Infinity]) {
    await validateVideoDuration(VIDEO, { apiKey: "test-key", fetch: metadata(duration) });
  }
});

Deno.test("continues unchecked after HTTP, network, timeout, or JSON failures", async () => {
  const failures: Array<typeof fetch> = [
    async () => new Response("unavailable", { status: 503 }),
    async () => {
      throw new TypeError("network failure");
    },
    async () => {
      throw new DOMException("timed out", "TimeoutError");
    },
    async () => new Response("invalid JSON"),
  ];
  for (const fetch of failures) {
    await validateVideoDuration(VIDEO, { apiKey: "test-key", fetch });
  }
});

Deno.test("continues unchecked without a configured API key", async () => {
  await validateVideoDuration(VIDEO, {
    apiKey: "",
    fetch: () => {
      throw new Error("must not request metadata without a key");
    },
  });
});
