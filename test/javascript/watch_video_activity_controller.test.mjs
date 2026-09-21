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

test("translation appears before the pause acknowledgement; pronunciation waits", async () => {
  const controllerPath = new URL(
    "../../app/javascript/controllers/watch_video_activity_controller.js",
    import.meta.url,
  );
  const source = await readFile(controllerPath, "utf8");

  const handler = source.slice(source.indexOf("handleTranslationClick(event)"), source.indexOf("resumeAfterTranslation()"));
  assert.ok(handler.indexOf("this.showTranslation(token, false)") < handler.indexOf("this.dispatch('pause'"));
  assert.match(handler, /afterPause: \(\{ wasPlaying \}\) =>/);
  assert.match(handler, /this\.playTranslationAudio\(this\.translationToken\)/);
  assert.doesNotMatch(handler.slice(handler.indexOf("afterPause:")), /this\.showTranslation\(token\)/);
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

test("repeated word clicks keep the translation open", async () => {
  const controllerPath = new URL(
    "../../app/javascript/controllers/watch_video_activity_controller.js",
    import.meta.url,
  );
  const source = await readFile(controllerPath, "utf8");
  const handlerStart = source.indexOf("handleTranslationClick(event)");
  const handlerEnd = source.indexOf("resumeAfterTranslation()", handlerStart);
  const handler = source.slice(handlerStart, handlerEnd);
  const openBranchStart = handler.indexOf("if (this.translationOpen)");
  const openBranchEnd = handler.indexOf("const generation", openBranchStart);
  const openBranch = handler.slice(openBranchStart, openBranchEnd);

  assert.match(openBranch, /if \(this\.translationToken === token\) return/);
  assert.match(openBranch, /this\.showTranslation\(token, !this\.translationPausePending\)/);
  assert.doesNotMatch(openBranch, /this\.hideTranslation\(\)/);
  assert.doesNotMatch(openBranch, /this\.dispatch\('resume'\)/);
  assert.match(handler, /this\.pausedForTranslation = this\.pausedForTranslation \|\| this\.videoPlaying/);
});
