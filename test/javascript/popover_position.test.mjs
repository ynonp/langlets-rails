import assert from "node:assert/strict";
import { test } from "node:test";

import { adjacentPopoverPosition } from "../../app/javascript/utils/popover_position.js";

const viewport = { viewportWidth: 390, viewportHeight: 844 };

test("centers a translation popup below the selected word", () => {
  const position = adjacentPopoverPosition({
    ...viewport,
    anchorRect: { left: 170, top: 300, width: 50, bottom: 330 },
    popupWidth: 180,
    popupHeight: 100,
  });

  assert.deepEqual(position, { left: 105, top: 336 });
});

test("clamps a translation popup to the viewport edges", () => {
  const leftEdge = adjacentPopoverPosition({
    ...viewport,
    anchorRect: { left: 0, top: 300, width: 20, bottom: 330 },
    popupWidth: 180,
    popupHeight: 100,
  });
  const rightEdge = adjacentPopoverPosition({
    ...viewport,
    anchorRect: { left: 375, top: 300, width: 15, bottom: 330 },
    popupWidth: 180,
    popupHeight: 100,
  });

  assert.equal(leftEdge.left, 8);
  assert.equal(rightEdge.left, 202);
});

test("places a translation popup above a word near the viewport bottom", () => {
  const position = adjacentPopoverPosition({
    ...viewport,
    anchorRect: { left: 170, top: 760, width: 50, bottom: 790 },
    popupWidth: 180,
    popupHeight: 100,
  });

  assert.deepEqual(position, { left: 105, top: 654 });
});
