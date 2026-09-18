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
