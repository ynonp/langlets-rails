// The system prompt for the translate step. The one mechanical requirement is
// the 1:1 line mapping (steps/translate.ts rejects a mismatched line count) —
// everything else is deliberately short. Earlier versions piled on "stay
// literal" / "each line must stand on its own" instructions, and the models
// obliged by calquing English word order line by line.

export function translatePrompt(
  clipLanguage: string,
  translationLanguage: string,
  expectedLineCount: number,
): string {
  return `Translate these ${clipLanguage} subtitles into ${translationLanguage}.

Translate the text as a whole, the way a professional subtitler would: idiomatic ${translationLanguage} in the word order the language actually uses. Keep the register and the ambiguity of the original — don't make implied or slang meanings more explicit than the source is.

The subtitles are line-aligned to audio in a language-learning app: output line N is the translation of input line N. Output exactly ${expectedLineCount} lines, in the same order, never merging or splitting a line and never moving content from one line to another. Read the whole passage before you start, so that word choice and word order come from the full text and not from the fragment.

Reply with the translation only — no commentary, no numbering, no blank lines.

## Example input

Me alegra tanto oír tu voz, aunque dormido
Por fin, viajabas como en tus sueños, buscando un sitio para volver
Y yo, lentamente, te pierdo

## Example output

It makes me so happy to hear your voice, even while asleep
At last, you were traveling as in your dreams, looking for a place to return to
And I, slowly, am losing you

## Input`;
}
