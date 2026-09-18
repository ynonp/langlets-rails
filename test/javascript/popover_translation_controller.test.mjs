import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

test("the translation popup marks and clears its selected token", async () => {
  const controllerPath = new URL(
    "../../app/javascript/controllers/popover_translation_controller.js",
    import.meta.url,
  );
  const source = await readFile(controllerPath, "utf8");

  assert.match(source, /this\.selectedToken\.setAttribute\('data-selected', ''\)/);
  assert.match(source, /this\.selectedToken\?\.removeAttribute\('data-selected'\)/);
  assert.match(source, /hidePopup\(\) \{\s+this\._clearSelectedToken\(\)/);
});

test("the explicit close control hides the popup and notifies playback owners", async () => {
  const controllerPath = new URL(
    "../../app/javascript/controllers/popover_translation_controller.js",
    import.meta.url,
  );
  const source = await readFile(controllerPath, "utf8");
  const start = source.indexOf("closePopup(event)");
  const end = source.indexOf("showPopup(ev)", start);
  const closePopup = source.slice(start, end);

  assert.match(closePopup, /event\.stopPropagation\(\)/);
  assert.match(closePopup, /this\.hidePopup\(\)/);
  assert.match(closePopup, /new CustomEvent\('translation:close'\)/);
});
