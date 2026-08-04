// YTDLP_NETWORK_NAMESPACE selects which `ip netns` yt-dlp downloads run
// through (see audioDownloadCommand in audio.ts). It accepts either a single
// namespace ("vpn", unchanged behavior) or a comma-separated list
// ("vpn1,vpn2,vpn3") to round-robin across several standing OpenVPN tunnels —
// useful because a tunnel tends to work fine until the day it doesn't, and at
// that point you want the next one tried automatically rather than a human
// noticing and reconfiguring.
//
// The namespace that last produced a usable download is preferred first, so
// in steady state every call tries the tunnel already known to work instead
// of round-robining needlessly. That preference is remembered in a small
// JSON file (YTDLP_VPN_STATE_FILE) so it survives a process restart — read
// once per process since main.ts/cli.ts are long-running, not once per call.

import { message } from "./retry.ts";

const DEFAULT_STATE_FILE = "/var/lib/langlets/vpn-state.json";

function stateFilePath(): string {
  return Deno.env.get("YTDLP_VPN_STATE_FILE") || DEFAULT_STATE_FILE;
}

export function parseNamespaceList(value: string | undefined): string[] {
  if (!value) return [];
  return value.split(",").map((entry) => entry.trim()).filter(Boolean);
}

// undefined = not yet loaded from disk this process; null = loaded, nothing recorded.
let lastGoodNamespace: string | null | undefined;

async function ensureLoaded(): Promise<void> {
  if (lastGoodNamespace !== undefined) return;
  try {
    const text = await Deno.readTextFile(stateFilePath());
    const data = JSON.parse(text);
    lastGoodNamespace = typeof data?.lastGood === "string" ? data.lastGood : null;
  } catch {
    lastGoodNamespace = null;
  }
}

// Test-only: the in-memory cache is deliberately load-once-per-process, so
// tests that vary YTDLP_VPN_STATE_FILE or YTDLP_NETWORK_NAMESPACE need a way
// to force the next call to read again.
export function resetVpnNamespaceStateForTest(): void {
  lastGoodNamespace = undefined;
}

// Namespaces to try, in order. Empty means "no namespace configured" (direct
// yt-dlp execution). A single configured namespace is returned as-is without
// touching the state file — there is no ordering decision to make. With two
// or more, the env var's list wins: a stale lastGood that has since fallen
// out of YTDLP_NETWORK_NAMESPACE is ignored and the configured order is used
// as given.
export async function orderedNamespaces(): Promise<string[]> {
  const configured = parseNamespaceList(Deno.env.get("YTDLP_NETWORK_NAMESPACE"));
  if (configured.length <= 1) return configured;

  await ensureLoaded();
  if (!lastGoodNamespace || !configured.includes(lastGoodNamespace)) return configured;

  return [lastGoodNamespace, ...configured.filter((ns) => ns !== lastGoodNamespace)];
}

// Persists the namespace a download just succeeded through, so the next call
// (and the next process, after a restart) tries it first. A no-op once it's
// already the recorded namespace, so the common case — the same healthy
// tunnel winning every time — costs no disk I/O beyond the first call.
export async function recordSuccessfulNamespace(namespace: string): Promise<void> {
  await ensureLoaded();
  if (lastGoodNamespace === namespace) return;
  lastGoodNamespace = namespace;

  const path = stateFilePath();
  try {
    const dir = path.includes("/") ? path.slice(0, path.lastIndexOf("/")) : ".";
    await Deno.mkdir(dir, { recursive: true });
    await Deno.writeTextFile(
      path,
      JSON.stringify({ lastGood: namespace, updatedAt: new Date().toISOString() }),
    );
  } catch (error) {
    console.warn(`Could not persist VPN namespace state to ${path}: ${message(error)}`);
  }
}
