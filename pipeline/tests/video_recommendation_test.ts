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
Deno.test("accepts Rails character limits for titles and vocabulary containing emoji", () => {
  const input = {
    ...context,
    imported_videos: [{ title: "أ".repeat(198) + "🎬📚", url: URL }],
    vocabulary: [{ word: "أ".repeat(99) + "📚", translation: "a".repeat(99) + "🎬" }],
  };
  assertEquals(parseRecommendationContext(input), input);
  assertThrows(() =>
    parseRecommendationContext({
      ...input,
      imported_videos: [{ title: "🎬".repeat(201), url: URL }],
    })
  );
  assertThrows(() =>
    parseRecommendationContext({
      ...input,
      vocabulary: [{ word: "📚".repeat(101), translation: "book" }],
    })
  );
});
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
Deno.test("requires the requested type and tells search to vary creators and topics", async () => {
  const varied = {
    ...context,
    preferred_content_type: "song" as const,
    excluded_channel: "Yesterday's creator",
    recent_recommendations: [{
      title: "Bakery dialogue",
      content_type: "dialogue",
      channel: "Yesterday's creator",
    }],
  };
  const selected = candidate(URL, `${URL}\nContent type: song`);
  assertEquals((await groundedVideo(selected, varied)).content_type, "song");
  await assertRejects(() =>
    groundedVideo(candidate(URL, `${URL}\nContent type: dialogue`), varied)
  );
  await assertRejects(() => groundedVideo(candidate(), varied));
  const parsed = parseRecommendationContext({
    ...varied,
    recent_recommendations: [{
      ...varied.recent_recommendations[0],
      email: "private@example.test",
    }],
  });
  assertEquals(parsed, varied);
  assertThrows(() => parseRecommendationContext({ ...varied, preferred_content_type: "unknown" }));
  assertThrows(() =>
    parseRecommendationContext({
      ...varied,
      recent_recommendations: Array(11).fill(varied.recent_recommendations[0]),
    })
  );
  const request: typeof fetch = (_input, init) => {
    const body = JSON.parse(String(init?.body));
    const instruction = body.systemInstruction.parts[0].text;
    assertEquals(instruction.includes("Today MUST be song"), true);
    assertEquals(instruction.includes("100% in French"), true);
    assertEquals(instruction.includes("English explanations"), true);
    assertEquals(instruction.includes("Match the difficulty"), true);
    assertEquals(instruction.includes("sampled source words"), true);
    assertEquals(instruction.includes("Exclude every video from the excluded_channel"), true);
    assertEquals(
      JSON.parse(body.contents[0].parts[0].text).excluded_channel,
      varied.excluded_channel,
    );
    return Promise.resolve(Response.json({ candidates: [selected] }));
  };
  assertEquals(
    (await recommendVideo(parsed, { apiKey: "test-key", request })).content_type,
    "song",
  );
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

Deno.test("preserves bounded learning evidence, strips identities and prioritizes dialect over variety", async () => {
  const learning = {
    ...context,
    learning_language: "Palestinian spoken Arabic (Levantine)",
    learning_language_code: "ar-JO",
    learning_language_native_name: "العربية الفلسطينية",
    vocabulary_source: "saved_words" as const,
    vocabulary: [{ word: "بيقهروني", translation: "annoy me", sentence: "ليش بيقهروني هيك" }],
    completed_lessons: [{
      title: "Conversation",
      lesson_title: "Relationships",
      url: URL,
      sentences: ["شو بدك؟"],
    }],
    preferred_content_type: "song" as const,
    variety_is_optional: true,
  };
  const parsed = parseRecommendationContext({
    ...learning,
    completed_lessons: [{ ...learning.completed_lessons[0], user_id: 123 }],
    vocabulary: [{ ...learning.vocabulary[0], email: "private@example.test" }],
  });
  assertEquals(parsed, learning);
  assertThrows(() =>
    parseRecommendationContext({
      ...learning,
      completed_lessons: Array(9).fill(learning.completed_lessons[0]),
    })
  );
  assertThrows(() =>
    parseRecommendationContext({
      ...learning,
      vocabulary: [{ ...learning.vocabulary[0], sentence: "أ".repeat(501) }],
    })
  );
  assertThrows(() =>
    parseRecommendationContext({
      ...learning,
      completed_lessons: [{ ...learning.completed_lessons[0], sentences: Array(6).fill("أ") }],
    })
  );
  const request: typeof fetch = (_input, init) => {
    const body = JSON.parse(String(init?.body));
    const instruction = body.systemInstruction.parts[0].text;
    assertEquals(instruction.includes("reject Modern Standard Arabic"), true);
    assertEquals(instruction.includes("strongest evidence"), true);
    assertEquals(instruction.includes("An import alone"), true);
    assertEquals(instruction.includes("Prefer song"), true);
    assertEquals(JSON.parse(body.contents[0].parts[0].text), learning);
    return Promise.resolve(
      Response.json({ candidates: [candidate(URL, `${URL}\nContent type: dialogue`)] }),
    );
  };
  assertEquals(
    (await recommendVideo(parsed, { apiKey: "test-key", request })).content_type,
    "dialogue",
  );
  await assertRejects(() => groundedVideo(candidate(), parsed));
});
