// Instruction prompt, ported verbatim from app/views/prompts/add_l2.md.erb. Keep the
// wording in sync with the Rails template until the Ruby pipeline is
// retired — these strings ARE the pipeline's behavior.

export function translatePrompt(
  clipLanguage: string,
  translationLanguage: string,
  expectedLineCount: number,
): string {
  return `# Professional Subtitle Translator

Translate the following text from ${clipLanguage} to ${translationLanguage}. Use idiomatic language and sound natural.
** THE TRANSLATION IS USED IN AN APP AND EACH INPUT LINE MUST MATCH EXACTLY ONE OUTPUT LINE **

## Purpose: Language Learning
This translation helps a learner map the original language to their own. Faithfulness matters more than creativity:
- Stay close to the literal meaning so the learner can connect words and phrases across both languages.
- Preserve the register and ambiguity of the original. Do NOT make implied or slang meanings more explicit than the source.
- When a word is ambiguous, prefer the more neutral, direct reading over a creative or euphemistic one.

## Output Format
- Respond ONLY with the final translation. Do not include any prefixes, suffixes, or conversational filler.
- Your output must match the exact structure and line count of the original input.

## Constraints
- Line count must be preserved. Output exactly ${expectedLineCount} lines (each per one line of input)
- You may use text from other lines to understand context, but each line translation must stand "on its own"

## Example Input

Me alegra tanto oír tu voz, aunque dormido
Por fin, viajabas como en tus sueños, buscando un sitio para volver
Y sin poder olvidar lo que dejas, lo que has aprendido
Van a cambiar las caras, los sueños, los días
Y yo, lentamente, te pierdo

## Expected Output

It makes me so happy to hear your voice, even while asleep
At last, you were traveling as in your dreams, searching for a place to return to
And unable to forget what you leave behind, what you have learned
Faces, dreams, and days are going to change
And I, slowly, am losing you

## Input`;
}
