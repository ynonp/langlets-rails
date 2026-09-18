import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

test("the exact segment start activates the first transcript sentence", async () => {
  const controllerPath = new URL(
    "../../app/javascript/controllers/watch_video_activity_controller.js",
    import.meta.url,
  );
  const source = await readFile(controllerPath, "utf8");

  assert.match(source, /findLastIndex\(t => t <= currentTime\)/);
});

test("translation UI and pronunciation run from the confirmed-pause callback", async () => {
  const controllerPath = new URL(
    "../../app/javascript/controllers/watch_video_activity_controller.js",
    import.meta.url,
  );
  const source = await readFile(controllerPath, "utf8");

  assert.match(source, /afterPause: \(\{ wasPlaying \}\) =>/);
  assert.match(source, /this\.showTranslation\(token\)/);
  assert.match(source, /new CustomEvent\('audio-cache:play'/);
});

test("opening a translation suppresses the karaoke word highlight", async () => {
  const controllerPath = new URL(
    "../../app/javascript/controllers/watch_video_activity_controller.js",
    import.meta.url,
  );
  const source = await readFile(controllerPath, "utf8");

  assert.match(source, /this\.clearKaraokeHighlight\(\);\s+const generation/);
  assert.match(source, /if \(this\.translationOpen\) \{\s+this\.clearKaraokeHighlight\(\);\s+return;/);
});
