// The system prompt for the translate step. The one mechanical requirement is
// the 1:1 line mapping (steps/translate.ts rejects a mismatched line count) —
// everything else is deliberately short. Earlier versions piled on "stay
// literal" / "each line must stand on its own" instructions, and the models
// obliged by calquing English word order line by line.

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

export function translatePrompt(
  clipLanguage: string,
  translationLanguage: string,
  expectedLineCount: number,
): string {
  const example = exampleFor(clipLanguage, translationLanguage);

  return `Translate these ${clipLanguage} subtitles into ${translationLanguage}.

Translate the text as a whole, the way a professional subtitler would: idiomatic ${translationLanguage} in the word order the language actually uses. Keep the register and the ambiguity of the original — don't make implied or slang meanings more explicit than the source is.

The subtitles are line-aligned to audio in a language-learning app: output line N is the translation of input line N. Output exactly ${expectedLineCount} lines, in the same order, never merging or splitting a line and never moving content from one line to another. Read the whole passage before you start, so that word choice and word order come from the full text and not from the fragment.

Reply with the translation only — no commentary, no numbering, no blank lines.

## Example input

${example.input}

## Example output

${example.output}

## Input`;
}
