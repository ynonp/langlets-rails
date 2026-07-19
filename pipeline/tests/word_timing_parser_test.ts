import { assertEquals } from "@std/assert";
import { parseWordTimings } from "../src/wordTimingParser.ts";
import { secondsToTimestamp, srtToSeconds, timestampToSeconds } from "../src/timestamps.ts";

Deno.test("timestamp conversions match the Rails helpers", () => {
  assertEquals(timestampToSeconds("00:05.00"), 5);
  assertEquals(timestampToSeconds("01:02.50"), 62.5);
  assertEquals(timestampToSeconds("01:00:01.5"), 3601.5);
  assertEquals(timestampToSeconds(""), null);
  assertEquals(timestampToSeconds("nope"), null);

  assertEquals(secondsToTimestamp(5), "00:05.00");
  assertEquals(secondsToTimestamp(62.5), "01:02.50");
  assertEquals(secondsToTimestamp(125.257), "02:05.26");

  assertEquals(srtToSeconds("00:00:06,500"), 6.5);
  assertEquals(srtToSeconds("00:03:45,000"), 225);
  assertEquals(srtToSeconds(""), null);
});

Deno.test("parses structured lines into the internal phrase shape", () => {
  const phrases = parseWordTimings({
    lines: [
      {
        line_start: "00:00:05,000",
        line_end: "00:00:08,000",
        line_text: "First line",
        words: [
          { word: "First", start: "00:00:05,000", end: "00:00:06,200" },
          { word: "line", start: "00:00:06,400", end: "00:00:08,000" },
        ],
      },
    ],
  });

  assertEquals(phrases.length, 1);
  const phrase = phrases[0];
  assertEquals(phrase.id, "phrase_1");
  assertEquals(phrase.text_l1, "First line");
  assertEquals(phrase.timestamp, "00:05.00");
  assertEquals(phrase.timestamp_end, "00:08.00");
  assertEquals(phrase.words[0], {
    text: "First",
    timestamp: "00:05.00",
    timestamp_end: "00:06.20",
    l1_start_index: 0,
    l1_end_index: 4,
  });
  assertEquals(phrase.words[1].l1_start_index, 6);
  assertEquals(phrase.words[1].l1_end_index, 9);
});

Deno.test("repeated words map to their occurrence in time order", () => {
  const phrases = parseWordTimings([
    {
      line_start: "00:00:01,000",
      line_end: "00:00:03,000",
      line_text: "la la land",
      words: [
        { word: "la", start: "00:00:01,000", end: "00:00:01,400" },
        { word: "la", start: "00:00:01,500", end: "00:00:01,900" },
        { word: "land", start: "00:00:02,000", end: "00:00:03,000" },
      ],
    },
  ]);

  const [first, second, third] = phrases[0].words;
  assertEquals([first.l1_start_index, first.l1_end_index], [0, 1]);
  assertEquals([second.l1_start_index, second.l1_end_index], [3, 4]);
  assertEquals([third.l1_start_index, third.l1_end_index], [6, 9]);
});

Deno.test("surrounding punctuation is stripped when locating a word", () => {
  const phrases = parseWordTimings([
    {
      line_start: "00:00:01,000",
      line_end: "00:00:02,000",
      line_text: "a lovers symphony,",
      words: [
        { word: "a", start: "00:00:01,000", end: "00:00:01,200" },
        { word: "lovers", start: "00:00:01,200", end: "00:00:01,500" },
        { word: "symphony,", start: "00:00:01,500", end: "00:00:02,000" },
      ],
    },
  ]);

  const symphony = phrases[0].words[2];
  // The span covers "symphony", not "symphony,".
  assertEquals(symphony.l1_start_index, 9);
  assertEquals(symphony.l1_end_index, 16);
});

Deno.test("square brackets are sanitized to parentheses", () => {
  const phrases = parseWordTimings([
    {
      line_start: "00:00:01,000",
      line_end: "00:00:02,000",
      line_text: "hello [chorus] again",
      words: [{ word: "[chorus]", start: "00:00:01,000", end: "00:00:02,000" }],
    },
  ]);

  assertEquals(phrases[0].text_l1, "hello (chorus) again");
  assertEquals(phrases[0].words[0].text, "(chorus)");
});

Deno.test("accepts a JSON string wrapped in markdown fences", () => {
  const json = JSON.stringify([
    {
      line_start: "00:00:01,000",
      line_end: "00:00:02,000",
      line_text: "Hello",
      words: [],
    },
  ]);
  const phrases = parseWordTimings("```json\n" + json + "\n```");
  assertEquals(phrases.length, 1);
  assertEquals(phrases[0].text_l1, "Hello");
});

Deno.test("missing line_text falls back to joining the words", () => {
  const phrases = parseWordTimings([
    {
      line_start: "00:00:01,000",
      line_end: "00:00:02,000",
      line_text: "",
      words: [
        { word: "Hola", start: "00:00:01,000", end: "00:00:01,400" },
        { word: "mundo", start: "00:00:01,500", end: "00:00:02,000" },
      ],
    },
  ]);
  assertEquals(phrases[0].text_l1, "Hola mundo");
});

Deno.test("phrases without text are dropped", () => {
  const phrases = parseWordTimings([
    { line_start: "00:00:01,000", line_end: "00:00:02,000", line_text: "", words: [] },
    { line_start: "00:00:03,000", line_end: "00:00:04,000", line_text: "Kept", words: [] },
  ]);
  assertEquals(phrases.length, 1);
  assertEquals(phrases[0].text_l1, "Kept");
});
