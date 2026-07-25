import assert from "node:assert/strict";
import { describe, test } from "node:test";
import InterpolatedPlaybackClock from "../../app/javascript/utils/interpolated_playback_clock.mjs";

describe("interpolated playback clock", () => {
  test("advances between sparse provider updates while playing", () => {
    let now = 1_000;
    const clock = new InterpolatedPlaybackClock(() => now);

    clock.setPosition(12.42);
    clock.setPlaying(true);
    now = 1_800;

    assert.equal(clock.currentPosition(), 13.22);
  });

  test("resynchronizes when the provider publishes an authoritative time", () => {
    let now = 1_000;
    const clock = new InterpolatedPlaybackClock(() => now);

    clock.setPosition(12.42);
    clock.setPlaying(true);
    now = 1_800;
    clock.setPosition(13.1);
    now = 2_000;

    assert.ok(Math.abs(clock.currentPosition() - 13.3) < Number.EPSILON * 100);
  });

  test("freezes the interpolated position when playback pauses", () => {
    let now = 1_000;
    const clock = new InterpolatedPlaybackClock(() => now);

    clock.setPosition(12.42);
    clock.setPlaying(true);
    now = 1_800;
    clock.setPlaying(false);
    now = 2_800;

    assert.equal(clock.currentPosition(), 13.22);
  });
});
