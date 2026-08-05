import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, test } from "node:test";

const controllerPath = new URL(
  "../../app/javascript/controllers/listen_activity_controller.js",
  import.meta.url
);

describe("listen activity timing modes", () => {
  test("word timing pauses at the missing token and reveals choices only then", async () => {
    const source = await readFile(controllerPath, "utf8");

    assert.match(source, /at >= missingStart/);
    assert.match(source, /pauseForQuestion\(this\.currentIndex\)/);
    assert.match(source, /if \(!this\.wordTimingValue\) this\.presentQuestion/);
  });

  test("phrase timing pauses at line end and completes through the shared event", async () => {
    const source = await readFile(controllerPath, "utf8");

    assert.match(source, /at >= Number\(current\.dataset\.end\)/);
    assert.match(source, /new CustomEvent\("activity:completed"/);
  });

  test("a correct selection resumes playback in either timing mode", async () => {
    const source = await readFile(controllerPath, "utf8");
    const selectWord = source.slice(source.indexOf("selectWord(event)"), source.indexOf("handleVideoEnd()"));

    assert.match(selectWord, /if \(!correct\) return/);
    assert.match(selectWord, /new CustomEvent\("listen-activity:play-video"\)/);
    assert.doesNotMatch(selectWord, /if \(this\.wordTimingValue\)/);
  });
});
