import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, test } from "node:test";

const source = async (relativePath) => readFile(new URL(relativePath, import.meta.url), "utf8");

describe("flashcard video", () => {
  test("configures each card's source and phrase timing", async () => {
    const flashcard = await source("../../app/javascript/controllers/flashcard_activity_controller.js");
    const player = await source("../../app/javascript/controllers/main_video_player_controller.js");

    assert.match(flashcard, /this\.dispatch\("card-change"/);
    assert.match(flashcard, /videoId: card\.video_id/);
    assert.match(player, /async configureSegment\(event\)/);
    assert.match(player, /await this\.player\.destroy\(\)/);
    assert.match(player, /this\.videoIdValue = videoId/);
    assert.match(player, /await this\.player\.seekTo\(this\.segmentStart\)/);

    const adapter = await source("../../app/javascript/players/youtube_adapter.js");
    assert.match(adapter, /return this\.player\.destroy\(\)/);
    assert.match(adapter, /return this\.player\.seekTo\(seconds, true\)/);
  });

  test("correct cards pause on the full-context L2 success message until Next", async () => {
    const flashcard = await source("../../app/javascript/controllers/flashcard_activity_controller.js");
    const correctBranch = flashcard.slice(
      flashcard.indexOf("if (selected.textContent.trim() === card.correct)"),
      flashcard.indexOf("} else {", flashcard.indexOf("if (selected.textContent.trim() === card.correct)"))
    );

    assert.match(correctBranch, /this\.showCardCompletion\(card\)/);
    assert.doesNotMatch(correctBranch, /setTimeout/);
    assert.match(flashcard, /completionTranslationTarget\.textContent = card\.phrase_l2/);
    assert.match(flashcard, /continue\(event\)/);
    assert.match(flashcard, /event\.preventDefault\(\)/);
    assert.match(flashcard, /this\.nextCard\(\)/);
  });

  test("shows an illustration, gives video precedence, and clears media on the next card", async () => {
    const sourceCode = await source("../../app/javascript/controllers/main_video_player_controller.js");
    const controllerCode = sourceCode.replace(/^import .*$/gm, "")
      .replace("extends Controller", "")
      .replace(/const ADAPTERS = \{[\s\S]*?\};/, "");
    const { default: Controller } = await import(`data:text/javascript,${encodeURIComponent(controllerCode)}`);
    const controller = new Controller();
    const element = () => {
      const classes = new Set();
      return {
        classList: {
          add: (name) => classes.add(name),
          remove: (name) => classes.delete(name),
          contains: (name) => classes.has(name),
          toggle: (name, show) => show ? classes.add(name) : classes.delete(name),
        },
        removeAttribute(name) { delete this[name]; },
      };
    };
    controller.playerContainerTarget = element();
    controller.mediaTarget = element();
    controller.cardIllustrationTarget = element();
    controller.hasCardIllustrationTarget = true;
    controller.stopPlaybackMonitoring = () => {};
    controller.initializePlayer = () => {};

    const illustrationUrl = "/word.webp";
    await controller.configureSegment({ detail: { illustrationUrl } });
    assert.equal(controller.cardIllustrationTarget.src, illustrationUrl);
    assert.equal(controller.mediaTarget.classList.contains("hidden"), true);
    assert.equal(controller.playerContainerTarget.classList.contains("hidden"), false);

    await controller.configureSegment({ detail: {
      illustrationUrl, videoId: "video", provider: "youtube", segmentStart: 2, segmentEnd: 4,
    } });
    assert.equal(controller.cardIllustrationTarget.src, undefined);
    assert.equal(controller.mediaTarget.classList.contains("hidden"), false);
    assert.equal(controller.playerContainerTarget.classList.contains("hidden"), false);

    await controller.configureSegment({ detail: {} });
    assert.equal(controller.cardIllustrationTarget.classList.contains("hidden"), true);
    assert.equal(controller.playerContainerTarget.classList.contains("hidden"), true);
  });
});
