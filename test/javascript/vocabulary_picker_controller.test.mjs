import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, test } from "node:test";

import PickerController from "../../app/javascript/controllers/vocabulary_picker_controller.js";

const controllerPath = new URL(
  "../../app/javascript/controllers/vocabulary_picker_controller.js",
  import.meta.url
);

// The picker drives a lot of DOM, but the part worth pinning down is the
// selection arithmetic: which words end up picked after a sequence of taps or a
// drag. Instantiate the class directly and stub only the two methods that
// touch the page.
function picker(words) {
  const controller = Object.create(PickerController.prototype);
  Object.assign(controller, {
    words,
    start: null,
    end: null,
    dragging: false,
    moved: false,
    pointerId: null,
    anchor: null,
    paintTokens() {},
    refresh() {}
  });
  return controller;
}

const tap = (controller, index) =>
  controller.pick({ currentTarget: { dataset: { index: String(index) } } });

const selected = (controller) => controller.pickedText;

describe("vocabulary picker — selecting a compound", () => {
  // The reported bug: a token can be more than one word ("me souviens"), and a
  // second tap has to grow the pick rather than replace it.
  test("tapping the next word extends the pick into a compound", () => {
    const p = picker([ "je", "me", "souviens", "de", "mon", "enfance" ]);

    tap(p, 1);
    assert.equal(selected(p), "me");

    tap(p, 2);
    assert.equal(selected(p), "me souviens");
    assert.deepEqual(p.range, [ 1, 2 ]);
  });

  test("it extends backwards too", () => {
    const p = picker([ "je", "me", "souviens", "de" ]);

    tap(p, 2);
    tap(p, 1);
    tap(p, 0);

    assert.equal(selected(p), "je me souviens");
    assert.deepEqual(p.range, [ 0, 2 ]);
  });

  test("tapping inside a compound collapses it back to that one word", () => {
    const p = picker([ "je", "me", "souviens", "de" ]);

    tap(p, 1);
    tap(p, 2);
    tap(p, 1);

    assert.equal(selected(p), "me");
  });

  test("tapping a word away from the pick starts a new one", () => {
    const p = picker([ "je", "me", "souviens", "de", "mon", "enfance" ]);

    tap(p, 1);
    tap(p, 2);
    tap(p, 5);

    assert.equal(selected(p), "enfance");
    assert.deepEqual(p.range, [ 5, 5 ]);
  });

  test("a compound keeps single spaces and loses surrounding punctuation", () => {
    const p = picker([ "quick,", "turn", "left", "here" ]);

    tap(p, 0);
    tap(p, 1);

    assert.equal(selected(p), "quick, turn");

    tap(p, 3);
    assert.equal(selected(p), "here");
  });
});

describe("vocabulary picker — dragging across words", () => {
  // The bug this guards: for touch input the pointer is implicitly captured by
  // the element that received pointerdown, so every pointermove is delivered to
  // *that* element and pointerenter never fires on the words underneath. The
  // drag therefore has to be hit-tested from the move's coordinates.
  test("a touch drag extends the pick even though every move targets the first word", () => {
    const p = picker([ "je", "me", "souviens", "de" ]);
    const anchor = { dataset: { index: "1" }, releasePointerCapture() {} };

    p.startDrag({ pointerId: 1, currentTarget: anchor });
    assert.equal(selected(p), "", "pointerdown alone must not commit a pick");

    // Coordinates resolve to a word; the event target stays the captured one.
    p.indexAtPoint = () => 2;
    p.dragOver({ pointerId: 1, clientX: 0, clientY: 0, currentTarget: anchor });

    assert.equal(selected(p), "me souviens");
    assert.equal(p.moved, true);
  });

  test("a drag suppresses the click that follows it", () => {
    const p = picker([ "je", "me", "souviens", "de" ]);
    const anchor = { dataset: { index: "1" }, releasePointerCapture() {} };

    p.startDrag({ pointerId: 1, currentTarget: anchor });
    p.indexAtPoint = () => 2;
    p.dragOver({ pointerId: 1, clientX: 0, clientY: 0 });
    tap(p, 2);

    assert.equal(selected(p), "me souviens", "the trailing click must not collapse the drag");
  });

  test("a press with no movement stays a tap", () => {
    const p = picker([ "je", "me", "souviens" ]);
    const anchor = { dataset: { index: "1" }, releasePointerCapture() {} };

    p.startDrag({ pointerId: 1, currentTarget: anchor });
    p.indexAtPoint = () => 1;
    p.dragOver({ pointerId: 1, clientX: 0, clientY: 0 });

    assert.equal(p.moved, false);
    tap(p, 1);
    assert.equal(selected(p), "me");
  });

  test("moves from a different pointer are ignored", () => {
    const p = picker([ "je", "me", "souviens" ]);
    const anchor = { dataset: { index: "1" }, releasePointerCapture() {} };

    p.startDrag({ pointerId: 1, currentTarget: anchor });
    p.indexAtPoint = () => 2;
    p.dragOver({ pointerId: 9, clientX: 0, clientY: 0 });

    assert.equal(p.moved, false);
  });
});

describe("vocabulary picker — touch safety", () => {
  // Binding the drag to pointerenter is the specific mistake that makes
  // compound selection work on a desktop and silently do nothing on a phone,
  // so the binding itself is asserted (the word still appears in a comment
  // explaining why it is not used).
  test("it never binds pointerenter, which does not fire during a touch drag", async () => {
    const source = await readFile(controllerPath, "utf8");

    assert.doesNotMatch(source, /pointerenter->/);
    assert.match(source, /releasePointerCapture/);
    assert.match(source, /indexAtPoint\(event\.clientX, event\.clientY\)/);
  });

  test("both Add screens listen for pointermove and neither binds pointerenter", async () => {
    const views = [
      "../../app/views/app/vocabulary_entries/new.html.erb",
      "../../app/views/vocabulary_entries/new.html.erb",
    ];

    for (const view of views) {
      const source = await readFile(new URL(view, import.meta.url), "utf8");

      assert.match(source, /pointermove@window->vocabulary-picker#dragOver/, view);
      assert.doesNotMatch(source, /pointerenter/, view);
    }
  });
});
