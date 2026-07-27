// Instruction prompt, ported verbatim from app/views/prompts/add_token_translations.md.erb. Keep the
// wording in sync with the Rails template until the Ruby pipeline is
// retired — these strings ARE the pipeline's behavior.

const exampleInput = `Don't (*Don't* you want me like I want you baby) |
you (Don't *you* want me like I want you baby) |
want (Don't you *want* me like I want you baby) |
you (Don't you want me like I want *you* baby) |
baby (Don't you want me like I want you *baby*) |`;

export const examples: Record<string, string> = {
  English: `Don't (*Don't* you want me like I want you baby) | Don't [auxiliary]
you (Don't *you* want me like I want you baby) | you [pronoun]
want (Don't you *want* me like I want you baby) | want [verb]
you (Don't you want me like I want *you* baby) | you [pronoun]
baby (Don't you want me like I want you *baby*) | baby [noun]`,
  Hebrew: `Don't (*Don't* you want me like I want you baby) | לא [auxiliary]
you (Don't *you* want me like I want you baby) | אתה [pronoun]
want (Don't you *want* me like I want you baby) | רוצה [verb]
you (Don't you want me like I want *you* baby) | אותך [pronoun]
baby (Don't you want me like I want you *baby*) | מותק [noun]`,
  French: `Don't (*Don't* you want me like I want you baby) | Ne [auxiliary]
you (Don't *you* want me like I want you baby) | tu [pronoun]
want (Don't you *want* me like I want you baby) | veux [verb]
you (Don't you want me like I want *you* baby) | toi [pronoun]
baby (Don't you want me like I want you *baby*) | bébé [noun]`,
  Spanish: `Don't (*Don't* you want me like I want you baby) | No [auxiliary]
you (Don't *you* want me like I want you baby) | tú [pronoun]
want (Don't you *want* me like I want you baby) | quieres [verb]
you (Don't you want me like I want *you* baby) | ti [pronoun]
baby (Don't you want me like I want you *baby*) | amor [noun]`,
  German: `Don't (*Don't* you want me like I want you baby) | Willst [auxiliary]
you (Don't *you* want me like I want you baby) | du [pronoun]
want (Don't you *want* me like I want you baby) | willst [verb]
you (Don't you want me like I want *you* baby) | dich [pronoun]
baby (Don't you want me like I want you *baby*) | Baby [noun]`,
  Arabic: `Don't (*Don't* you want me like I want you baby) | لا [auxiliary]
you (Don't *you* want me like I want you baby) | أنت [pronoun]
want (Don't you *want* me like I want you baby) | تريد [verb]
you (Don't you want me like I want *you* baby) | إياك [pronoun]
baby (Don't you want me like I want you *baby*) | حبيبي [noun]`,
};

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
   marked word as it is used in that context, followed by its ${clipLanguage}
   part of speech in square brackets. Use exactly one of: noun, proper_noun,
   verb, adjective, adverb, pronoun, determiner, preposition, conjunction,
   auxiliary, particle, interjection, numeral, punctuation, other.
4. Classify the marked source-language word in this specific context, not the
   translated word. Proper names and place names must be [proper_noun].
5. Never skip a line. If the marked word is punctuation-only or has no standalone
   meaning, repeat it after the |.
6. Output ONLY the translated lines — no preamble, no numbering, no markdown, no code fences.

${
    examples[translationLanguage]
      ? `## Example Input:
${exampleInput}

## Expected Output:
${examples[translationLanguage]}
`
      : ""
  }

Now translate the following. Output one line per input line, in order:`;
}
