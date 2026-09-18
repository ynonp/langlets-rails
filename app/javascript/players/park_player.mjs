const PLAYING = 1;
const BUFFERING = 3;

const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

function settled(state) {
  return state !== PLAYING && state !== BUFFERING;
}

async function waitUntil(check, { timeoutMs, pollMs, wait, now }) {
  const deadline = now() + timeoutMs;

  do {
    if (await check()) return true;
    if (now() >= deadline) return false;
    await wait(pollMs);
  } while (true);
}

// Providers differ in what seekTo does to playback state. YouTube preserves a
// confirmed pause, while TikTok documents pause/seek as independent postMessage
// commands. Pause on both sides of the seek, then verify both observable state
// and position so the shared controller can expose one dependable operation.
export async function parkPlayerAt(player, target, options = {}) {
  const position = Number(target);
  if (!player || !Number.isFinite(position)) return false;

  const timeoutMs = options.timeoutMs ?? 750;
  const pollMs = options.pollMs ?? 25;
  const tolerance = options.tolerance ?? 0.75;
  const wait = options.wait ?? delay;
  const now = options.now ?? (() => performance.now());
  const waitOptions = { timeoutMs, pollMs, wait, now };

  try {
    await player.pauseVideo();
    await waitUntil(async () => settled(await player.getPlayerState()), waitOptions);

    // A retry covers providers that acknowledge pause before their seek has
    // reached an unbuffered target. Both attempts finish with an explicit pause.
    for (let attempt = 0; attempt < 2; attempt += 1) {
      await player.seekTo(position);
      await player.pauseVideo();

      const stopped = await waitUntil(
        async () => settled(await player.getPlayerState()),
        waitOptions,
      );
      const positioned = await waitUntil(async () => {
        const current = Number(await player.getCurrentTime());
        return Number.isFinite(current) && Math.abs(current - position) <= tolerance;
      }, waitOptions);

      if (stopped && positioned) return true;
    }
  } catch (_error) {
    // Turbo can remove/destroy a provider while an asynchronous park is in
    // flight. The controller's generation check suppresses stale UI updates.
  }

  return false;
}

