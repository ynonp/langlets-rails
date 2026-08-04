import { assertEquals } from "@std/assert";
import {
  orderedNamespaces,
  parseNamespaceList,
  recordSuccessfulNamespace,
  resetVpnNamespaceStateForTest,
} from "../src/vpnNamespace.ts";

// Each test owns YTDLP_NETWORK_NAMESPACE / YTDLP_VPN_STATE_FILE and resets the
// module's load-once cache, so tests don't see each other's env vars or the
// namespace a previous test recorded as last-good.
async function withVpnEnv(
  env: { namespaces?: string; stateFile?: string },
  fn: () => Promise<void>,
) {
  // Only manage the lifecycle of a state file we create ourselves — a caller
  // that passes its own path (e.g. to simulate state surviving a restart)
  // owns creating and removing it.
  const ownsStateFile = env.stateFile === undefined;
  const stateFile = env.stateFile ?? (await Deno.makeTempFile({ prefix: "vpn_state_" }));
  if (ownsStateFile) await Deno.remove(stateFile).catch(() => {});

  const previousNamespaces = Deno.env.get("YTDLP_NETWORK_NAMESPACE");
  const previousStateFile = Deno.env.get("YTDLP_VPN_STATE_FILE");
  if (env.namespaces === undefined) Deno.env.delete("YTDLP_NETWORK_NAMESPACE");
  else Deno.env.set("YTDLP_NETWORK_NAMESPACE", env.namespaces);
  Deno.env.set("YTDLP_VPN_STATE_FILE", stateFile);
  resetVpnNamespaceStateForTest();

  try {
    await fn();
  } finally {
    if (previousNamespaces === undefined) Deno.env.delete("YTDLP_NETWORK_NAMESPACE");
    else Deno.env.set("YTDLP_NETWORK_NAMESPACE", previousNamespaces);
    if (previousStateFile === undefined) Deno.env.delete("YTDLP_VPN_STATE_FILE");
    else Deno.env.set("YTDLP_VPN_STATE_FILE", previousStateFile);
    resetVpnNamespaceStateForTest();
    if (ownsStateFile) await Deno.remove(stateFile).catch(() => {});
  }
}

Deno.test("parseNamespaceList treats unset as no namespaces", () => {
  assertEquals(parseNamespaceList(undefined), []);
  assertEquals(parseNamespaceList(""), []);
});

Deno.test("parseNamespaceList keeps a single value backward compatible", () => {
  assertEquals(parseNamespaceList("vpn"), ["vpn"]);
});

Deno.test("parseNamespaceList splits and trims a comma list", () => {
  assertEquals(parseNamespaceList("vpn1, vpn2 ,vpn3"), ["vpn1", "vpn2", "vpn3"]);
});

Deno.test("no env var means no namespace", async () => {
  await withVpnEnv({}, async () => {
    assertEquals(await orderedNamespaces(), []);
  });
});

Deno.test("a single namespace is returned as-is, no state file involved", async () => {
  await withVpnEnv({ namespaces: "vpn", stateFile: "/nonexistent/dir/state.json" }, async () => {
    assertEquals(await orderedNamespaces(), ["vpn"]);
  });
});

Deno.test("with no recorded state, the configured order is used", async () => {
  await withVpnEnv({ namespaces: "vpn1,vpn2,vpn3" }, async () => {
    assertEquals(await orderedNamespaces(), ["vpn1", "vpn2", "vpn3"]);
  });
});

Deno.test("the last successful namespace is tried first", async () => {
  await withVpnEnv({ namespaces: "vpn1,vpn2,vpn3" }, async () => {
    await recordSuccessfulNamespace("vpn2");
    assertEquals(await orderedNamespaces(), ["vpn2", "vpn1", "vpn3"]);
  });
});

Deno.test("the env var's list wins over a stale recorded namespace", async () => {
  const stateFile = await Deno.makeTempFile({ prefix: "vpn_state_" });
  await Deno.writeTextFile(stateFile, JSON.stringify({ lastGood: "foobar" }));

  await withVpnEnv({ namespaces: "vpn1,vpn2,vpn3", stateFile }, async () => {
    assertEquals(await orderedNamespaces(), ["vpn1", "vpn2", "vpn3"]);
  });
  await Deno.remove(stateFile).catch(() => {});
});

Deno.test("a recorded namespace survives a process restart (cache reload)", async () => {
  const stateFile = await Deno.makeTempFile({ prefix: "vpn_state_" });
  await Deno.remove(stateFile).catch(() => {});

  await withVpnEnv({ namespaces: "vpn1,vpn2,vpn3", stateFile }, async () => {
    await recordSuccessfulNamespace("vpn3");
  });

  // Simulate the next process: fresh cache, same state file on disk.
  Deno.env.set("YTDLP_NETWORK_NAMESPACE", "vpn1,vpn2,vpn3");
  Deno.env.set("YTDLP_VPN_STATE_FILE", stateFile);
  resetVpnNamespaceStateForTest();
  try {
    assertEquals(await orderedNamespaces(), ["vpn3", "vpn1", "vpn2"]);
  } finally {
    Deno.env.delete("YTDLP_NETWORK_NAMESPACE");
    Deno.env.delete("YTDLP_VPN_STATE_FILE");
    resetVpnNamespaceStateForTest();
    await Deno.remove(stateFile).catch(() => {});
  }
});

Deno.test("recording the already-current namespace does not touch disk", async () => {
  await withVpnEnv({ namespaces: "vpn1,vpn2" }, async () => {
    await recordSuccessfulNamespace("vpn1");
    const stateFile = Deno.env.get("YTDLP_VPN_STATE_FILE")!;
    await Deno.remove(stateFile).catch(() => {});

    // Cache still says vpn1 is current — recording it again must be a no-op,
    // not recreate the file we just removed.
    await recordSuccessfulNamespace("vpn1");
    await assertFileMissing(stateFile);
  });
});

async function assertFileMissing(path: string) {
  let exists = true;
  try {
    await Deno.stat(path);
  } catch {
    exists = false;
  }
  assertEquals(exists, false);
}
