import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, test } from "node:test";

const controllerPath = new URL(
  "../../app/javascript/controllers/progress_controller.js",
  import.meta.url
);

describe("lesson progress controller", () => {
  test("moves the playhead from logical inline-start for LTR and RTL layouts", async () => {
    const source = await readFile(controllerPath, "utf8");

    assert.match(source, /dotTarget\.style\.insetInlineStart/);
    assert.doesNotMatch(source, /dotTarget\.style\.left/);
  });
});
