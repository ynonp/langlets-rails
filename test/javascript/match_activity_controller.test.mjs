import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, test } from "node:test";

const controllerPath = new URL(
  "../../app/javascript/controllers/match_activity_controller.js",
  import.meta.url
);

describe("match phrase completion", () => {
  test("a correct answer pauses on the completion bar without duplicating the phrase", async () => {
    const source = await readFile(controllerPath, "utf8");
    const correctBranch = source.slice(
      source.indexOf("if (isCorrect)"),
      source.indexOf("} else {", source.indexOf("if (isCorrect)"))
    );

    assert.match(correctBranch, /this\.showPhraseCompletion\(\)/);
    assert.doesNotMatch(correctBranch, /t\("match\.correct"\)/);
    assert.doesNotMatch(correctBranch, /setTimeout/);
    assert.doesNotMatch(correctBranch, /this\.moveToNextPhrase\(\)/);
  });

  test("Next advances intermediate phrases", async () => {
    const source = await readFile(controllerPath, "utf8");
    const completionStart = source.indexOf("  showPhraseCompletion()");
    const completionEnd = source.indexOf("showFeedback(", completionStart);
    const completionFlow = source.slice(completionStart, completionEnd);

    assert.doesNotMatch(completionFlow, /completionL1Target/);
    assert.doesNotMatch(completionFlow, /completionL2Target/);
    assert.match(completionFlow, /continue\(event\)/);
    assert.match(completionFlow, /event\.preventDefault\(\)/);
    assert.match(completionFlow, /this\.moveToNextPhrase\(\)/);
    assert.match(completionFlow, /if \(isFinalPhrase\) return/);
  });
});
