import type { SoundDictionary } from "./fuzzyword.ts";

// Common words grouped by similar readings. Homophones can look up the same
// neighbors but are excluded from each other’s alternatives.
const pairs = [
  [["映画", "えいが"], ["英語", "えいご"]],
  [["朝", "あさ"], ["傘", "かさ"]],
  [["駅", "えき"], ["咳", "せき"]],
  [["電車", "でんしゃ"], ["電話", "でんわ"]],
  [["昼", "ひる"], ["夜", "よる"]],
  [["お茶", "おちゃ"], ["お餅", "おもち"]],
  [["公園", "こうえん"], ["公演", "こうえん"], ["応援", "おうえん"]],
  [["買う", "かう"], ["飼う", "かう"], ["会う", "あう"]],
  [["雨", "あめ"], ["飴", "あめ"], ["亀", "かめ"]],
  [["山", "やま"], ["浜", "はま"]],
  [["空", "そら"], ["皿", "さら"]],
  [["坂", "さか"], ["傘", "かさ"]],
  [["花", "はな"], ["鼻", "はな"], ["棚", "たな"]],
  [["声", "こえ"], ["上", "うえ"]],
  [["風", "かぜ"], ["影", "かげ"]],
  [["赤い", "あかい"], ["甘い", "あまい"]],
  [["見る", "みる"], ["着る", "きる"]],
  [["聞く", "きく"], ["引く", "ひく"]],
  [["近い", "ちかい"], ["違い", "ちがい"]],
  [["お金", "おかね"], ["おかず", "おかず"]],
  [["時計", "とけい"], ["模型", "もけい"]],
  [["カメラ", "かめら"], ["カメ", "かめ"]],
  [["コーヒー", "こーひー"], ["コーチ", "こーち"]],
  [["バス", "ばす"], ["パス", "ぱす"]],
] as const;

export const japaneseSounds: SoundDictionary = {
  lookup(word) {
    const alternatives = new Set<string>();
    for (const group of pairs) {
      const source = group.find(([spelling, reading]) => word === spelling || word === reading);
      if (!source) continue;
      for (const [spelling, reading] of group) {
        if (reading !== source[1]) alternatives.add(spelling);
      }
    }
    return [...alternatives];
  },
};
