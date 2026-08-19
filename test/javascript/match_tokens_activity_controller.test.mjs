import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, test } from "node:test";

const controllerPath = new URL(
  "../../app/javascript/controllers/match_tokens_activity_controller.js",
  import.meta.url
);

describe("match tokens activity page transitions", () => {
  test("reveals the next page without automatically playing token audio", async () => {
    const source = await readFile(controllerPath, "utf8");
    const methodStart = source.indexOf("  maybeAdvancePage()");
    const methodEnd = source.indexOf("  handleFailedMatch(", methodStart);

    assert.notEqual(methodStart, -1);
    assert.notEqual(methodEnd, -1);

    const maybeAdvancePage = source.slice(methodStart, methodEnd);

    assert.match(maybeAdvancePage, /nextPage\.classList\.remove\(['"]hidden['"]\)/);
    assert.doesNotMatch(maybeAdvancePage, /playTokenAudio/);
    assert.doesNotMatch(maybeAdvancePage, /audio-cache:play/);
  });
});
