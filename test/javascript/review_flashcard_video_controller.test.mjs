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
  });
});
