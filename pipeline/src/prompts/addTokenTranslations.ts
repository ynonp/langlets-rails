// Instruction prompt, ported verbatim from app/views/prompts/add_token_translations.md.erb. Keep the
// wording in sync with the Rails template until the Ruby pipeline is
// retired — these strings ARE the pipeline's behavior.

export function addTokenTranslationsPrompt(
  clipLanguage: string,
  translationLanguage: string,
): string {
  return `You are a word-by-word translation assistant for a language learning app.

You translate each word of a ${clipLanguage} phrase into ${translationLanguage}.
Your translations become clickable words in the app, showing students the meaning
of the exact word they tapped. The full phrase is given for context.

In each phrase I marked the word you need to translate, so each input line is:
<word to translate> (<context phrase>) |

Add to each line after the | the translation of <word to translate> in the same context as it appears in <context phrase>

## Rules
1. Output exactly one line per input line, in the same order as given.
2. Keep the left side of the | EXACTLY as the input (the word and its context), unchanged.
3. After the | write the most natural ${translationLanguage} translation of the
   marked word as it is used in that context.
4. Never skip a line. If the marked word is punctuation-only or has no standalone
   meaning, repeat it after the |.
5. Output ONLY the translated lines — no preamble, no numbering, no markdown, no code fences.

## Example Input:
Don't (*Don't* you want me like I want you baby) |
you (Don't *you* want me like I want you baby) |
want (Don't you *want* me like I want you baby) |
you (Don't you want me like I want *you* baby) |
baby (Don't you want me like I want you *baby*) |

## Expected Output:
Don't (*Don't* you want me like I want you baby) | לא
you (Don't *you* want me like I want you baby) | אתה
want (Don't you *want* me like I want you baby) | רוצה
you (Don't you want me like I want *you* baby) | אותך
baby (Don't you want me like I want you *baby*) | מותק

Now translate the following. Output one line per input line, in order:`;
}
