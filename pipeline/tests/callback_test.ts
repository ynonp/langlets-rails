import { assert, assertEquals, assertRejects } from "@std/assert";
import { HttpCallbackClient } from "../src/callback.ts";
import { SIGNATURE_HEADER, TIMESTAMP_HEADER, verify } from "../src/hmac.ts";
import type { PatchOp } from "../src/types.ts";

const SECRET = "callback-secret";
const OPS: PatchOp[] = [{ op: "set", path: "lessons", value: "# Title" }];

function fakeFetch(responder: (call: number, body: string) => Response) {
  const requests: Array<{ url: string; body: string; headers: Headers }> = [];
  const fetchFn = async (input: URL | RequestInfo, init?: RequestInit): Promise<Response> => {
    const body = String(init?.body ?? "");
    requests.push({ url: String(input), body, headers: new Headers(init?.headers) });
    return await Promise.resolve(responder(requests.length, body));
  };
  return { fetchFn, requests };
}

Deno.test("patch POSTs the ops with a valid HMAC signature", async () => {
  const { fetchFn, requests } = fakeFetch(() => new Response("ok"));
  const client = new HttpCallbackClient("https://rails.example/cb", SECRET, {
    fetchFn,
    baseDelayMs: 0,
  });

  await client.patch(OPS);

  assertEquals(requests.length, 1);
  assertEquals(requests[0].url, "https://rails.example/cb");
  assertEquals(JSON.parse(requests[0].body), { ops: OPS });

  const signature = requests[0].headers.get(SIGNATURE_HEADER)!;
  const timestamp = requests[0].headers.get(TIMESTAMP_HEADER)!;
  assert(await verify(SECRET, timestamp, requests[0].body, signature));
});

Deno.test("patch skips the network entirely for an empty batch", async () => {
  const { fetchFn, requests } = fakeFetch(() => new Response("ok"));
  const client = new HttpCallbackClient("https://rails.example/cb", SECRET, { fetchFn });
  await client.patch([]);
  assertEquals(requests.length, 0);
});

Deno.test("patch retries server errors and eventually succeeds", async () => {
  const { fetchFn, requests } = fakeFetch((call) =>
    call < 3 ? new Response("boom", { status: 500 }) : new Response("ok")
  );
  const client = new HttpCallbackClient("https://rails.example/cb", SECRET, {
    fetchFn,
    baseDelayMs: 0,
  });

  await client.patch(OPS);
  assertEquals(requests.length, 3);
});

Deno.test("patch gives up after maxRetries and surfaces the failure", async () => {
  const { fetchFn, requests } = fakeFetch(() => new Response("boom", { status: 500 }));
  const client = new HttpCallbackClient("https://rails.example/cb", SECRET, {
    fetchFn,
    baseDelayMs: 0,
    maxRetries: 2,
  });

  await assertRejects(() => client.patch(OPS), Error, "callback responded 500");
  assertEquals(requests.length, 3);
});

Deno.test("patch does not retry client errors (Rails rejected the patch)", async () => {
  const { fetchFn, requests } = fakeFetch(() => new Response("bad signature", { status: 401 }));
  const client = new HttpCallbackClient("https://rails.example/cb", SECRET, {
    fetchFn,
    baseDelayMs: 0,
  });

  await assertRejects(() => client.patch(OPS), Error, "callback responded 401");
  assertEquals(requests.length, 1);
});
