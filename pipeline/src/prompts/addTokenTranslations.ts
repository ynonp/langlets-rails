const exampleInput = `Don't (*Don't* you want me like I want you baby) |
you (Don't *you* want me like I want you baby) |
want (Don't you *want* me like I want you baby) |
you (Don't you want me like I want *you* baby) |
baby (Don't you want me like I want you *baby*) |`;

// The legacy prompt selected examples by target language. Production retains
// that established behavior; the only new instruction is the narrow scope
// guard in buildPrompt below.
export const examples: Record<string, string> = {
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
  Greek: `Don't (*Don't* you want me like I want you baby) | Μη [auxiliary]
you (Don't *you* want me like I want you baby) | εσύ [pronoun]
want (Don't you *want* me like I want you baby) | θέλεις [verb]
you (Don't you want me like I want *you* baby) | εσένα [pronoun]
baby (Don't you want me like I want you *baby*) | μωρό [noun]`,
  Swedish: `Don't (*Don't* you want me like I want you baby) | inte [auxiliary]
you (Don't *you* want me like I want you baby) | du [pronoun]
want (Don't you *want* me like I want you baby) | vill [verb]
you (Don't you want me like I want *you* baby) | dig [pronoun]
baby (Don't you want me like I want you *baby*) | älskling [noun]`,
};

export function addTokenTranslationsPrompt(
  clipLanguage: string,
  translationLanguage: string,
): string {
  return buildPrompt(clipLanguage, translationLanguage, true);
}

// Used only by the comparison script to reproduce the prompt before the
// narrow scope guard was added.
export function legacyAddTokenTranslationsPrompt(
  clipLanguage: string,
  translationLanguage: string,
): string {
  return buildPrompt(clipLanguage, translationLanguage, false);
}

function buildPrompt(
  clipLanguage: string,
  translationLanguage: string,
  includeScopeGuard: boolean,
): string {
  const scopeGuard = includeScopeGuard
    ? `
4. Translate only the marked word. Do not include meaning contributed by adjacent words.
`
    : "";
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
${scopeGuard}${
    includeScopeGuard ? "5" : "4"
  }. Classify the marked source-language word in this specific context, not the
   translated word. Proper names and place names must be [proper_noun].
${
    includeScopeGuard
      ? "6"
      : "5"
  }. Never skip a line. If the marked word is punctuation-only or has no standalone
   meaning, repeat it after the |.
${
    includeScopeGuard
      ? "7"
      : "6"
  }. Output ONLY the translated lines — no preamble, no numbering, no markdown, no code fences.

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
