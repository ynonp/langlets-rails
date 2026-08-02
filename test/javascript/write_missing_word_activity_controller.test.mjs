import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, test } from "node:test";

const controllerPath = new URL(
  "../../app/javascript/controllers/write_missing_word_activity_controller.js",
  import.meta.url
);

describe("write missing word activity completion", () => {
  test("emits the shared activity completion event consumed by progress tracking", async () => {
    const source = await readFile(controllerPath, "utf8");

    assert.match(source, /new CustomEvent\(["']activity:completed["']/);
    assert.doesNotMatch(source, /this\.dispatch\(["']completed["']/);
  });
});
