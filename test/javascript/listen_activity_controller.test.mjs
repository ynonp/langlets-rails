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
    assert.match(source, /this\.stageTarget\.classList\.remove\("hidden"\)/);
    assert.match(source, /\.listen-word\[data-missing='true'\].*toggleAttribute\("data-revealed"/);
  });

  test("phrase timing pauses at line end and completes through the shared event", async () => {
    const source = await readFile(controllerPath, "utf8");

    assert.match(source, /at >= Number\(current\.dataset\.end\)/);
    assert.match(source, /new CustomEvent\("activity:completed"/);
  });

  test("a correct selection resumes playback in either timing mode", async () => {
    const source = await readFile(controllerPath, "utf8");
    const selectWord = source.slice(source.indexOf("selectWord(event)"), source.indexOf("\n  handleVideoEnd()"));

    assert.match(selectWord, /if \(!correct\) return/);
    assert.match(selectWord, /new CustomEvent\("listen-activity:play-video"\)/);
    assert.doesNotMatch(selectWord, /if \(this\.wordTimingValue\)/);
  });
});

// Exercise the real controller methods with only its browser imports stubbed.
const source = await readFile(controllerPath, "utf8");
const moduleSource = "class Controller {}\nconst animate = () => {};\n" + source.replace(/^import .*$/gm, "");
const { default: ListenController } = await import(`data:text/javascript;base64,${Buffer.from(moduleSource).toString("base64")}`);

function activity() {
  const classList = { add() {}, remove() {}, toggle() {} };
  const events = [];
  const phrase = () => ({
    dataset: { hasMissing: "true", start: "10", end: "20" },
    classList,
    toggleAttribute() {},
    querySelector: () => null,
    querySelectorAll: () => [],
  });
  const controller = Object.assign(Object.create(ListenController.prototype), {
    phraseTargets: [phrase(), phrase()],
    startInstructionTarget: { classList },
    stageTarget: { classList },
    wordSelectionTarget: { classList },
    completionTarget: { classList },
    element: { dispatchEvent: event => events.push(event.type) },
    awardXp() {},
  });
  controller.connect();
  return { controller, events, answer: { currentTarget: { dataset: { correct: "true", word: "answer" }, classList } } };
}

describe("listen activity playback completion", () => {
  test("the last answer after segment end completes without replaying the clip", () => {
    const { controller, events, answer } = activity();
    controller.answered.add(0);
    // The last progress callback can still point at the previous phrase.
    controller.handleVideoEnd();
    assert.equal(controller.currentIndex, 1);
    controller.selectWord(answer);
    assert.equal(controller.completed, true);
    assert.deepEqual(events, ["listen-activity:pause-video", "activity:completed"]);
  });

  test("questions skipped by scrubbing can be answered before completion", () => {
    const { controller, events, answer } = activity();
    controller.currentIndex = 1;
    controller.handleVideoEnd();
    assert.equal(controller.currentIndex, 0);
    controller.selectWord(answer);
    assert.equal(controller.currentIndex, 1);
    assert.equal(controller.completed, false);
    controller.selectWord(answer);
    assert.equal(controller.completed, true);
    assert.equal(events.includes("listen-activity:play-video"), false);
  });

  test("a correct answer before segment end resumes playback", () => {
    const { controller, events, answer } = activity();
    controller.selectWord(answer);
    assert.deepEqual(events, ["listen-activity:play-video"]);
    assert.equal(controller.completed, false);
  });

  test("duplicate end and answer events cannot repeat completion or XP", () => {
    const { controller, events, answer } = activity();
    let xp = 0;
    controller.awardXp = amount => xp += amount;
    controller.answered.add(0);
    controller.handleVideoEnd();
    controller.selectWord(answer);
    controller.selectWord(answer);
    controller.handleVideoEnd();
    assert.equal(xp, 2);
    assert.equal(events.filter(event => event === "activity:completed").length, 1);
  });
});
