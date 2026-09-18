import assert from "node:assert/strict";
import { describe, test } from "node:test";
import { pausePlayerAndWait } from "../../app/javascript/players/pause_player.mjs";
import { PlayerState } from "../../app/javascript/players/player_states.js";

function stateHarness() {
  const listeners = new Set();
  return {
    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    emit(state) {
      listeners.forEach((listener) => listener(state));
    },
    get size() {
      return listeners.size;
    },
  };
}

describe("pause confirmation", () => {
  test("sends pause immediately and resolves only after PAUSED", async () => {
    const states = stateHarness();
    let pauseCalls = 0;
    let timeout;
    const player = {
      getPlayerState: async () => PlayerState.PLAYING,
      pauseVideo() { pauseCalls += 1; },
    };

    const resultPromise = pausePlayerAndWait(player, states.subscribe, {
      setTimer(callback) { timeout = callback; return 1; },
      clearTimer() { timeout = null; },
    });

    assert.equal(pauseCalls, 1);
    assert.equal(states.size, 1);

    // Let the initial state query record that playback was active before the
    // provider reports completion of the pause command.
    await Promise.resolve();
    states.emit(PlayerState.PAUSED);
    assert.deepEqual(await resultPromise, { confirmed: true, wasPlaying: true });
    assert.equal(states.size, 0);
    assert.equal(timeout, null);
  });

  test("an already paused player confirms without waiting for another callback", async () => {
    const states = stateHarness();
    const player = {
      getPlayerState: async () => PlayerState.PAUSED,
      pauseVideo() {},
    };

    const result = await pausePlayerAndWait(player, states.subscribe);

    assert.deepEqual(result, { confirmed: true, wasPlaying: false });
    assert.equal(states.size, 0);
  });

  test("falls back after the bounded timeout", async () => {
    const states = stateHarness();
    let timeout;
    const player = {
      getPlayerState: async () => PlayerState.UNSTARTED,
      pauseVideo() {},
    };

    const resultPromise = pausePlayerAndWait(player, states.subscribe, {
      setTimer(callback) { timeout = callback; return 1; },
      clearTimer() {},
    });

    timeout();
    assert.deepEqual(await resultPromise, { confirmed: false, wasPlaying: false });
    assert.equal(states.size, 0);
  });
});
