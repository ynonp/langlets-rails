import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

test("text-only mode restores the lesson media box before Turbo changes activities", async () => {
  const controllerPath = new URL(
    "../../app/javascript/controllers/full_player_controller.js",
    import.meta.url,
  );
  const source = await readFile(controllerPath, "utf8");

  assert.match(source, /resetForFrameNavigation\(\) \{\s+this\.restoreMediaBox\(\)/);
  assert.match(source, /if \(!this\.textOnlyActive \|\| !this\.hasMediaBoxTarget\) return/);
  assert.match(source, /this\.mediaBoxTarget\.classList\.remove\("hidden"\)/);
});
