import { PlayerState } from "./player_states.js";

const DEFAULT_TIMEOUT_MS = 800;

const playbackStopped = (state) => (
  state === PlayerState.PAUSED || state === PlayerState.ENDED
);

// Issue the pause command immediately, then wait for the provider's state
// callback before allowing UI that depends on silence to continue. YouTube's
// pause promise only confirms that the iframe command was sent, and TikTok's
// postMessage command has no acknowledgement, so neither is sufficient by
// itself. The timeout keeps a missing provider callback from swallowing the
// learner's word click forever.
export function pausePlayerAndWait(player, subscribeToState, {
  timeoutMs = DEFAULT_TIMEOUT_MS,
  setTimer = setTimeout,
  clearTimer = clearTimeout,
} = {}) {
  let wasPlaying = false;

  return new Promise((resolve) => {
    let settled = false;
    let timer;

    const finish = (confirmed) => {
      if (settled) return;
      settled = true;
      unsubscribe();
      clearTimer(timer);
      resolve({ confirmed, wasPlaying });
    };

    const observeState = (state) => {
      if (state === PlayerState.PLAYING) wasPlaying = true;
      if (playbackStopped(state)) finish(true);
    };

    const unsubscribe = subscribeToState(observeState);
    timer = setTimer(() => finish(false), timeoutMs);

    // Read the initial state in parallel with the pause. The command must not
    // wait behind an iframe round trip just to decide whether it is needed.
    Promise.resolve(player.getPlayerState()).then(observeState).catch(() => {});

    try {
      Promise.resolve(player.pauseVideo()).catch(() => finish(false));
    } catch (_error) {
      finish(false);
    }
  });
}

export { DEFAULT_TIMEOUT_MS };
