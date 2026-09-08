import { assert, assertEquals } from "@std/assert";
import { ChineseSounds, pronunciationDistance } from "../src/chineseSounds.ts";
import { dictionaryFor } from "../src/fuzzyword.ts";
import { addSimilarSound, buildChineseSimilarSoundLine } from "../src/steps/addSimilarSound.ts";
import { makeCtx } from "./helpers.ts";

const dictionary = new ChineseSounds([
  { term: "买", count: 1000, readings: ["mai3"] },
  { term: "買", count: 500, readings: ["mai3"] },
  { term: "卖", count: 900, readings: ["mai4"] },
  { term: "賣", count: 400, readings: ["mai4"] },
  { term: "马", count: 200, readings: ["ma3"] },
  { term: "我", count: 99999, readings: ["wo3"] },
  { term: "学习", count: 1000, readings: ["xue2 xi2"] },
  { term: "学期", count: 800, readings: ["xue2 qi1"] },
  { term: "学历", count: 900, readings: ["xue2 li4"] },
  { term: "雪地", count: 9999, readings: ["xue3 di4"] },
  { term: "行", count: 800, readings: ["xing2", "hang2"] },
]);
const first = () => 0;

Deno.test("Chinese matching uses pronunciation, excludes homophones and deduplicates readings", () => {
  assertEquals(dictionary.lookup("买"), ["卖", "马"]);
  assertEquals(dictionary.lookup("買"), ["卖", "马"]);
  assertEquals(dictionary.lookup("学习"), ["学历", "学期"]);
  assertEquals(dictionary.lookup("行"), []);
  assertEquals(dictionary.lookup("不存在的词"), []);
});

Deno.test("Chinese distance accounts for syllables, tones, and umlauts", () => {
  assertEquals(pronunciationDistance("mai3", "mai4"), 0.25);
  assertEquals(pronunciationDistance("xue2 xi2", "xue2 qi1"), 1.25);
  assertEquals(pronunciationDistance("lv4", "lu4"), 1);
  assertEquals(pronunciationDistance("xue2 xi2", "xue3 di4"), Infinity);
  assertEquals(pronunciationDistance("xue2 xi2", "xi2"), Infinity);
});

Deno.test("Chinese replacements allow short words and preserve punctuation, spacing, and occurrence", () => {
  assertEquals(buildChineseSimilarSoundLine(dictionary, "我 买 茶。", first), "我 [卖] 茶。");
  assertEquals(buildChineseSimilarSoundLine(dictionary, "买，  买！", () => 0.75), "买，  [马]！");
  assertEquals(buildChineseSimilarSoundLine(dictionary, "学习！", first), "[学历]！");
  assertEquals(buildChineseSimilarSoundLine(dictionary, "我喜欢学习。", first), "我喜欢学习。");
  assertEquals(buildChineseSimilarSoundLine(null, "我 买 茶。", first), "我 买 茶。");
});

Deno.test("Chinese pipeline keeps untranslated lines aligned with their original phrases", async () => {
  const { ctx, store } = makeCtx({
    clipLanguage: "Chinese",
    data: {
      phrases: ["好。", "我 买 茶。", "123！", "学习。"].map((text, i) => ({
        id: String(i),
        text_l1: text,
        timestamp: "00:01.00",
        timestamp_end: "00:02.00",
        words: [],
      })),
    },
  });
  ctx.fuzzywordFor = (code) => {
    assertEquals(code, "zh");
    return Promise.resolve(dictionary);
  };
  ctx.random = first;
  await addSimilarSound(ctx);
  assertEquals(store.data.similar_sounds, "好。\n我 [卖] 茶。\n123！\n[学历]。");
});

Deno.test("bundled Chinese dictionary contains clean words, usable readings, and audible alternatives", async () => {
  const data = JSON.parse(
    await Deno.readTextFile(new URL("../data/zh-pronunciation.json", import.meta.url)),
  );
  assert(data.entries.length > 10000);
  const terms = new Set<string>();
  for (const entry of data.entries) {
    assert(/^\p{Script=Han}{1,4}$/u.test(entry.term));
    assert(entry.count >= 100);
    assert(!terms.has(entry.term));
    terms.add(entry.term);
    assert(entry.readings.length > 0);
    for (const reading of entry.readings) {
      assert(/^[a-z]+[1-5]( [a-z]+[1-5])*$/.test(reading));
      assertEquals(reading.split(" ").length, [...entry.term].length);
    }
  }
  const real = await dictionaryFor("zh");
  assert(real);
  assert(real.lookup("知道").includes("迟到"));
  assert(real.lookup("学习").includes("学期"));
  assert(real.lookup("买").includes("卖"));
});
