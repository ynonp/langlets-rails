// HMAC-SHA256 request authentication, used in both directions: Rails signs the
// trigger request, the pipeline signs every callback. The signature covers
// `${timestamp}.${body}` so a captured request can't be replayed outside the
// allowed clock skew.

export const SIGNATURE_HEADER = "x-pipeline-signature";
export const TIMESTAMP_HEADER = "x-pipeline-timestamp";
export const MAX_CLOCK_SKEW_SECONDS = 5 * 60;

const encoder = new TextEncoder();

async function hmacKey(secret: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

export async function sign(secret: string, timestamp: string, body: string): Promise<string> {
  const key = await hmacKey(secret);
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(`${timestamp}.${body}`));
  return [...new Uint8Array(signature)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Constant-time hex comparison so signature checks don't leak prefix length.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function verify(
  secret: string,
  timestamp: string,
  body: string,
  signature: string,
  { maxSkewSeconds = MAX_CLOCK_SKEW_SECONDS, now = Date.now }: {
    maxSkewSeconds?: number;
    now?: () => number;
  } = {},
): Promise<boolean> {
  const ts = Number(timestamp);
  if (!Number.isFinite(ts)) return false;
  if (Math.abs(now() / 1000 - ts) > maxSkewSeconds) return false;

  const expected = await sign(secret, timestamp, body);
  return timingSafeEqual(expected, signature);
}

// Build the auth headers for an outgoing signed request.
export async function signedHeaders(secret: string, body: string): Promise<Record<string, string>> {
  const timestamp = String(Math.floor(Date.now() / 1000));
  return {
    "content-type": "application/json",
    [TIMESTAMP_HEADER]: timestamp,
    [SIGNATURE_HEADER]: await sign(secret, timestamp, body),
  };
}

// Verify an incoming Request; returns the raw body when authentic, null otherwise.
export async function verifyRequest(secret: string, request: Request): Promise<string | null> {
  const signature = request.headers.get(SIGNATURE_HEADER);
  const timestamp = request.headers.get(TIMESTAMP_HEADER);
  if (!signature || !timestamp) return null;

  const body = await request.text();
  return (await verify(secret, timestamp, body, signature)) ? body : null;
}
