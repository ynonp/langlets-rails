import assert from "node:assert/strict";
import { describe, test } from "node:test";
import {
  crossedSentenceBoundary,
  nextSentenceBoundaryIndex,
  playbackJumped,
} from "../../app/javascript/players/sentence_boundaries.mjs";

describe("sentence-by-sentence playback boundaries", () => {
  test("selects the first sentence end after the current playback position", () => {
    assert.equal(nextSentenceBoundaryIndex([2.5, 5, 8], 2.5), 1);
    assert.equal(nextSentenceBoundaryIndex([2.5, 5, 8], 8), 3);
  });

  test("pauses only when ordinary playback crosses a boundary", () => {
    assert.equal(crossedSentenceBoundary(2.45, 2.55, 2.5), true);
    assert.equal(crossedSentenceBoundary(1, 4, 2.5), false);
    assert.equal(crossedSentenceBoundary(2.55, 2.6, 2.5), false);
  });

  test("recognizes scrubbing so it does not cause a surprise pause", () => {
    assert.equal(playbackJumped(1, 4), true);
    assert.equal(playbackJumped(1, 1.1), false);
  });
});
