import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { afterEach, beforeEach, describe, test } from "node:test";

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

// Stub only the imported browser helpers; run the actual controller methods.
const source = await readFile(controllerPath, "utf8");
const moduleSource = "class Controller {}\nconst t = key => key;\n" +
  source.replace(/^import .*$/gm, "");
const { default: RecallController } = await import(`data:text/javascript;base64,${Buffer.from(moduleSource).toString("base64")}`);

function recall() {
  return Object.assign(Object.create(RecallController.prototype), {
    cardsValue: [{ id: 9, correct: "tiempo", options: ["tiempo", "queda"] }],
    currentIndex: 0,
    isReviewLessonValue: true,
    recallUrlValue: "/review_lessons/recall",
    activityIdValue: 7,
    neededHelp: false,
    savingRecall: false,
    answerTarget: { value: "tiempo", disabled: false, select() {} },
    checkButtonTarget: { disabled: false },
    hintButtonTarget: { disabled: false, classList: { toggle() {} } },
    hintOptionsTarget: { querySelectorAll: () => [], replaceChildren() {}, classList: { remove() {} } },
    writeInterfaceTarget: { classList: { add() {} } },
    feedbackTarget: { classList: { add() {} } },
    awardXp() {}, playCardAudio() {}, revealCorrectAnswer() {},
    showCardCompletion() { this.completed = true; }
  });
}

describe("vocabulary recall scheduling", () => {
  let originalFetch, originalDocument;
  beforeEach(() => {
    originalFetch = globalThis.fetch;
    originalDocument = globalThis.document;
    globalThis.document = {
      querySelector: () => ({ content: "csrf" }),
      createElement: () => ({ dataset: {} })
    };
  });
  afterEach(() => {
    globalThis.fetch = originalFetch;
    globalThis.document = originalDocument;
  });

  test("records unaided recall before showing completion", async () => {
    const p = recall();
    let payload;
    globalThis.fetch = async (url, options) => {
      assert.equal(url, "/review_lessons/recall");
      assert.equal(options.headers["X-CSRF-Token"], "csrf");
      assert.equal(p.completed, undefined);
      payload = JSON.parse(options.body);
      return { ok: true };
    };
    await p.completeCard(p.cardsValue[0], 2);
    assert.deepEqual(payload, { activity_id: 7, phrase_token_id: 9, remembered: true });
    assert.equal(p.completed, true);
  });

  test("a wrong attempt followed by a correct answer records relearning", async () => {
    const p = recall();
    p.answerTarget.value = "wrong";
    p.checkAnswer();
    assert.equal(p.neededHelp, true);
    globalThis.fetch = async (_url, options) => {
      assert.equal(JSON.parse(options.body).remembered, false);
      return { ok: true };
    };
    p.answerTarget.value = "tiempo";
    await p.completeCard(p.cardsValue[0], 2);
    assert.equal(p.completed, true);
  });

  test("using a hint records relearning", async () => {
    const p = recall();
    p.showHint();
    assert.equal(p.neededHelp, true);
    globalThis.fetch = async (_url, options) => {
      assert.equal(JSON.parse(options.body).remembered, false);
      return { ok: true };
    };
    await p.completeCard(p.cardsValue[0], 1);
  });

  test("a failed save keeps the card retryable without advancing", async () => {
    const p = recall();
    globalThis.fetch = async () => ({ ok: false });
    await p.completeCard(p.cardsValue[0], 2);
    assert.equal(p.completed, undefined);
    assert.equal(p.savingRecall, false);
    assert.equal(p.answerTarget.disabled, false);
    assert.equal(p.feedbackTarget.textContent, "write_missing_word.save_failed");
    globalThis.fetch = async () => ({ ok: true });
    await p.completeCard(p.cardsValue[0], 2);
    assert.equal(p.completed, true);
  });

  test("course activities do not submit vocabulary recall results", async () => {
    const p = recall();
    p.isReviewLessonValue = false;
    globalThis.fetch = async () => { assert.fail("course activity submitted a review"); };
    await p.completeCard(p.cardsValue[0], 2);
    assert.equal(p.completed, true);
  });

  test("repeated completion clicks submit once", async () => {
    const p = recall();
    let calls = 0;
    globalThis.fetch = async () => { calls += 1; return { ok: true }; };
    await Promise.all([p.completeCard(p.cardsValue[0], 2), p.completeCard(p.cardsValue[0], 2)]);
    assert.equal(calls, 1);
  });
});
