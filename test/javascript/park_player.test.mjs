import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, test } from "node:test";
import { parkPlayerAt } from "../../app/javascript/players/park_player.mjs";

const immediateOptions = {
  timeoutMs: 0,
  pollMs: 0,
  wait: async () => {},
  now: () => 0,
};

describe("parking a segmented video player", () => {
  test("initial playback seeks to the segment without parking", async () => {
    const controller = await readFile(
      new URL("../../app/javascript/controllers/main_video_player_controller.js", import.meta.url),
      "utf8",
    );
    const start = controller.indexOf("async seekToSegmentStartIfBefore(event)");
    const end = controller.indexOf("async parkAtSegmentStart", start);
    const initialPlaybackGuard = controller.slice(start, end);

    assert.match(initialPlaybackGuard, /await this\.player\.seekTo\(segmentStart\)/);
    assert.doesNotMatch(initialPlaybackGuard, /this\.parkAtSegmentStart/);
  });

  test("pauses on both sides of the seek and confirms the target", async () => {
    const calls = [];
    let state = 1;
    let currentTime = 19;
    const player = {
      async pauseVideo() {
        calls.push("pause");
        state = 2;
      },
      async seekTo(target) {
        calls.push(["seek", target]);
        currentTime = target;
        // Model a provider whose seek starts playback even after a pause.
        state = 1;
      },
      async getPlayerState() { return state; },
      async getCurrentTime() { return currentTime; },
    };

    assert.equal(await parkPlayerAt(player, 12, immediateOptions), true);
    assert.deepEqual(calls, ["pause", ["seek", 12], "pause"]);
    assert.equal(state, 2);
  });

  test("retries when the first seek does not reach the requested position", async () => {
    const seeks = [];
    let currentTime = 30;
    const player = {
      async pauseVideo() {},
      async seekTo(target) {
        seeks.push(target);
        currentTime = seeks.length === 1 ? target - 4 : target;
      },
      async getPlayerState() { return 2; },
      async getCurrentTime() { return currentTime; },
    };

    assert.equal(await parkPlayerAt(player, 10, immediateOptions), true);
    assert.deepEqual(seeks, [10, 10]);
  });

  test("fails safely if a provider is destroyed during the operation", async () => {
    const player = {
      async pauseVideo() { throw new Error("destroyed"); },
      async seekTo() {},
      async getPlayerState() { return 2; },
      async getCurrentTime() { return 0; },
    };

    assert.equal(await parkPlayerAt(player, 10, immediateOptions), false);
  });
});
