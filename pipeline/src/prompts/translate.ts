// The system prompt for the translate step. The one mechanical requirement is
// the 1:1 line mapping — everything else is deliberately short. Earlier
// versions piled on "stay literal" / "each line must stand on its own"
// instructions, and the models obliged by calquing English word order line by
// line.
//
// Every input line carries its own number and every output line must repeat
// it. Asking for a bare line count instead was not enough: on a transcript
// with a long run of one-word fragment lines ("وكل." / "كل." / "اللي.") the
// model merges neighbours into the one natural clause they make together, and
// an unnumbered response gives no way to tell *which* lines it merged — the
// whole run fails on the count alone. Numbers make the damage addressable, so
// steps/translate.ts can ask again for exactly the lines that went missing.

interface Example {
  input: string;
  output: string;
}

const SPANISH = `Me alegra tanto oír tu voz, aunque dormido
Por fin, viajabas como en tus sueños, buscando un sitio para volver
Y yo, lentamente, te pierdo`;

const ARABIC = `أنا سعيد جدًا لسماع صوتك، حتى وأنا نائم
أخيرًا، كنت تسافر كما في أحلامك، تبحث عن مكان لتعود إليه
وأنا، ببطء، أفقدك`;

const FRENCH = `Je suis si heureux d'entendre ta voix, même endormi
Enfin, tu voyageais comme dans tes rêves, cherchant un endroit où revenir
Et moi, lentement, je te perds`;

const ENGLISH = `It makes me so happy to hear your voice, even while asleep
At last, you were traveling as in your dreams, looking for a place to return to
And I, slowly, am losing you`;

const HEBREW = `כל כך שמח לשמוע את קולך, גם כשאני ישן
סוף סוף נסעת כמו בחלומות שלך, מחפש מקום לחזור אליו
ואני, לאט לאט, מאבד אותך`;

// Worked examples for the pairs we actually see in production. The exact
// (clip, translation) pair matters far more than either language alone — a
// model asked to translate Arabic into Hebrew and shown a Spanish->English
// example gets no grounding in the right script or direction at all, which
// is how the sentence-level step ended up echoing an Arabic source back
// as its own "Hebrew" translation while the word-level step (whose examples
// already keyed off the real target language) got Hebrew right.
const examples: Record<string, Record<string, Example>> = {
  Arabic: {
    Hebrew: { input: ARABIC, output: HEBREW },
    English: { input: ARABIC, output: ENGLISH },
  },
  Spanish: {
    English: { input: SPANISH, output: ENGLISH },
    Hebrew: { input: SPANISH, output: HEBREW },
  },
  French: {
    English: { input: FRENCH, output: ENGLISH },
    Hebrew: { input: FRENCH, output: HEBREW },
  },
};

// Every pair we don't have a real example for falls back to whichever
// Spanish example matches the target: Spanish->Hebrew for a Hebrew target,
// Spanish->English for everything else (English or any other language).
function exampleFor(clipLanguage: string, translationLanguage: string): Example {
  return examples[clipLanguage]?.[translationLanguage] ??
    (translationLanguage === "Hebrew" ? examples.Spanish.Hebrew : examples.Spanish.English);
}

// `requestedLineNumbers` names the subset to translate on a repair pass: the
// input still carries the whole chunk so context is never lost, but only those
// lines are wanted back. Omit it to ask for every input line.
export function translatePrompt(
  clipLanguage: string,
  translationLanguage: string,
  expectedLineCount: number,
  requestedLineNumbers?: number[],
): string {
  const example = exampleFor(clipLanguage, translationLanguage);
  const scope = requestedLineNumbers
    ? `Output exactly ${expectedLineCount} lines — one for each of these input line numbers, in this order: ${
      requestedLineNumbers.join(", ")
    }. Every other input line is context only: read it, but do not translate it.`
    : `Output exactly ${expectedLineCount} lines, one for each numbered input line, in the same order.`;

  return `Translate these ${clipLanguage} subtitles into ${translationLanguage}.

Translate the text as a whole, the way a professional subtitler would: idiomatic ${translationLanguage} in the word order the language actually uses. Keep the register and the ambiguity of the original — don't make implied or slang meanings more explicit than the source is.

The subtitles are line-aligned to audio in a language-learning app. Every input line begins with its line number. Begin each output line with the same number followed by a period and a space, then the translation of that line and nothing else. Repeat the numbers exactly as given — they are not always consecutive.

${scope}

Never merge two input lines into one output line and never split one input line across two. A line that is only a fragment — a single word, a bare conjunction, a repetition of the line before it — still gets its own numbered output line, translated as the fragment it is. Read the whole passage before you start, so that word choice and word order come from the full text and not from the fragment.

Reply with the numbered translation only — no commentary, no blank lines, nothing outside the numbered lines.

## Example input

${numberedExample(example.input)}

## Example output

${numberedExample(example.output)}

## Input`;
}

function numberedExample(text: string): string {
  return text
    .split("\n")
    .map((line, index) => `${index + 1}. ${line}`)
    .join("\n");
}
