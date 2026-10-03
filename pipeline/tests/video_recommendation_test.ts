import { assertEquals, assertRejects, assertThrows } from "@std/assert";
import {
  canonicalVideo,
  groundedVideo,
  parseRecommendationContext,
  recommendVideo,
} from "../src/videoRecommendation.ts";

const URL = "https://www.youtube.com/watch?v=kJQP7kiw5Fk";
const context = {
  learning_language: "French",
  imported_videos: [],
  vocabulary: [],
  previous_suggestions: [],
};
function candidate(uri = URL, text = URL) {
  return {
    finishReason: "STOP",
    content: { parts: [{ text }] },
    groundingMetadata: {
      webSearchQueries: ["site:youtube.com French bakery"],
      groundingChunks: [{ web: { uri } }],
      searchEntryPoint: { renderedContent: "<div>Google Search</div>" },
    },
  };
}
Deno.test("selects only a cited video and preserves search attribution", async () => {
  assertEquals(await groundedVideo(candidate(), context), {
    url: URL,
    search_suggestions: "<div>Google Search</div>",
  });
  assertEquals(
    (await groundedVideo(candidate(URL, "https://www.youtube.com/watch?v=abcdefghijk"), context))
      .url,
    null,
  );
  assertEquals(
    (await groundedVideo(candidate(), { ...context, previous_suggestions: [URL] })).url,
    null,
  );
});
Deno.test("requires search evidence and completion", async () => {
  await assertRejects(() => groundedVideo({ ...candidate(), groundingMetadata: {} }, context));
  await assertRejects(() => groundedVideo({ ...candidate(), finishReason: "MAX_TOKENS" }, context));
});
Deno.test("resolves Google citations without following arbitrary redirect destinations", async () => {
  const uri = "https://vertexaisearch.cloud.google.com/grounding-api-redirect/example";
  const request: typeof fetch = (_input, init) => {
    assertEquals(init?.redirect, "manual");
    assertEquals(init?.method, "HEAD");
    return Promise.resolve(new Response(null, { status: 302, headers: { location: URL } }));
  };
  assertEquals((await groundedVideo(candidate(uri, uri), context, request)).url, URL);
  const unsafe: typeof fetch = () =>
    Promise.resolve(
      new Response(null, { status: 302, headers: { location: "http://127.0.0.1/private" } }),
    );
  assertEquals((await groundedVideo(candidate(uri), context, unsafe)).url, null);
  assertEquals(canonicalVideo("https://evil.example/youtube.com/watch?v=kJQP7kiw5Fk"), null);
});
Deno.test("rejects excessive context and sends the configured Google tool", async () => {
  assertThrows(() =>
    parseRecommendationContext({
      ...context,
      vocabulary: Array(41).fill({ word: "pain", translation: "bread" }),
    })
  );
  assertEquals(parseRecommendationContext({ ...context, email: "private@example.test" }), context);
  const request: typeof fetch = (_input, init) => {
    const body = JSON.parse(String(init?.body));
    assertEquals(body.tools, [{ google_search: {} }]);
    assertEquals(body.generationConfig.responseMimeType, undefined);
    assertEquals(new Headers(init?.headers).get("x-goog-api-key"), "test-key");
    return Promise.resolve(Response.json({ candidates: [candidate()] }));
  };
  assertEquals((await recommendVideo(context, { apiKey: "test-key", request })).url, URL);
});
