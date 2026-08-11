import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, test } from "node:test";

const controllerPath = new URL(
  "../../app/javascript/controllers/homepage_video_picker_controller.js",
  import.meta.url
);

describe("homepage video picker", () => {
  test("copies the selected URL, marks one card, and focuses the build field", async () => {
    const source = await readFile(controllerPath, "utf8");

    assert.match(source, /this\.inputTarget\.value = selected\.dataset\.videoUrl/);
    assert.match(source, /card\.setAttribute\("aria-pressed", card === selected \? "true" : "false"\)/);
    assert.match(source, /this\.inputTarget\.focus/);
    assert.match(source, /this\.inputTarget\.scrollIntoView/);
  });
});
