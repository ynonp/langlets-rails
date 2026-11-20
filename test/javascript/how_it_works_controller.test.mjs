import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, test } from "node:test";

const controllerPath = new URL(
  "../../app/javascript/controllers/how_it_works_controller.js",
  import.meta.url
);
const partialPath = new URL(
  "../../app/views/courses/_how_it_works.html.erb",
  import.meta.url
);

describe("homepage how it works animations", () => {
  test("keeps the server-rendered final state for reduced motion", async () => {
    const source = await readFile(controllerPath, "utf8");

    assert.match(source, /prefers-reduced-motion: reduce\)"\)\.matches\) return/);
  });

  test("only plays stages on screen and cancels runs when leaving or disconnecting", async () => {
    const source = await readFile(controllerPath, "utf8");

    assert.match(source, /new IntersectionObserver/);
    assert.match(source, /entry\.isIntersecting \? this\.start\(entry\.target\) : this\.stop\(entry\.target\)/);
    assert.match(source, /this\.observer\?\.disconnect\(\)/);
    assert.match(source, /run\.cancelled = true/);
  });

  test("has a scene for every stage the partial renders", async () => {
    const source = await readFile(controllerPath, "utf8");
    const partial = await readFile(partialPath, "utf8");
    const scenes = partial.match(/hiw_steps = %w\[([^\]]+)\]/)[1].trim().split(/\s+/);

    assert.deepEqual(scenes, ["transcribe", "split", "words", "practice"]);
    for (const scene of scenes) assert.match(source, new RegExp(`\\n  ${scene}: \\{`));
  });
});
