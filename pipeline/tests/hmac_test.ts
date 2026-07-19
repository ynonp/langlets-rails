import { assert, assertEquals, assertFalse } from "@std/assert";
import {
  SIGNATURE_HEADER,
  sign,
  signedHeaders,
  TIMESTAMP_HEADER,
  verify,
  verifyRequest,
} from "../src/hmac.ts";

const SECRET = "test-secret";

Deno.test("sign/verify roundtrip", async () => {
  const timestamp = String(Math.floor(Date.now() / 1000));
  const signature = await sign(SECRET, timestamp, '{"a":1}');
  assert(await verify(SECRET, timestamp, '{"a":1}', signature));
});

Deno.test("verify rejects a tampered body", async () => {
  const timestamp = String(Math.floor(Date.now() / 1000));
  const signature = await sign(SECRET, timestamp, '{"a":1}');
  assertFalse(await verify(SECRET, timestamp, '{"a":2}', signature));
});

Deno.test("verify rejects the wrong secret", async () => {
  const timestamp = String(Math.floor(Date.now() / 1000));
  const signature = await sign("other-secret", timestamp, "body");
  assertFalse(await verify(SECRET, timestamp, "body", signature));
});

Deno.test("verify rejects a stale timestamp (replay protection)", async () => {
  const stale = String(Math.floor(Date.now() / 1000) - 3600);
  const signature = await sign(SECRET, stale, "body");
  assertFalse(await verify(SECRET, stale, "body", signature));
  // The same request inside the window is fine.
  assert(await verify(SECRET, stale, "body", signature, { maxSkewSeconds: 7200 }));
});

Deno.test("verify rejects a non-numeric timestamp", async () => {
  const signature = await sign(SECRET, "not-a-number", "body");
  assertFalse(await verify(SECRET, "not-a-number", "body", signature));
});

Deno.test("signedHeaders produce a request verifyRequest accepts", async () => {
  const body = JSON.stringify({ ops: [] });
  const request = new Request("https://example.com/callback", {
    method: "POST",
    headers: await signedHeaders(SECRET, body),
    body,
  });
  assertEquals(await verifyRequest(SECRET, request), body);
});

Deno.test("verifyRequest rejects missing headers", async () => {
  const request = new Request("https://example.com/callback", { method: "POST", body: "{}" });
  assertEquals(await verifyRequest(SECRET, request), null);
});

Deno.test("verifyRequest rejects a forged signature", async () => {
  const body = "{}";
  const headers = await signedHeaders(SECRET, body);
  headers[SIGNATURE_HEADER] = headers[SIGNATURE_HEADER].replace(/./, "0");
  const request = new Request("https://example.com/callback", { method: "POST", headers, body });
  // Either the signature differs or (if the first char was already 0) keep it valid.
  const result = await verifyRequest(SECRET, request);
  const expected = await sign(SECRET, headers[TIMESTAMP_HEADER], body);
  assertEquals(result, headers[SIGNATURE_HEADER] === expected ? body : null);
});
