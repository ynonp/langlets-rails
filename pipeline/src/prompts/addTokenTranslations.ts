export const exampleInputs: Record<string, string> = {
  Hebrew: `לא (אתה *לא* רוצה אותי כמו שאני רוצה אותך מותק) |
אתה (*אתה* לא רוצה אותי כמו שאני רוצה אותך מותק) |
רוצה (אתה לא *רוצה* אותי כמו שאני רוצה אותך מותק) |
אותך (אתה לא רוצה אותי כמו שאני רוצה *אותך* מותק) |
מותק (אתה לא רוצה אותי כמו שאני רוצה אותך *מותק*) |`,
  French: `pas (Tu ne me veux *pas* comme je te veux bébé) |
Tu (*Tu* ne me veux pas comme je te veux bébé) |
veux (Tu ne me *veux* pas comme je te veux bébé) |
te (Tu ne me veux pas comme je *te* veux bébé) |
bébé (Tu ne me veux pas comme je te veux *bébé*) |`,
  Spanish: `No (*No* me quieres como yo te quiero cariño) |
quieres (No me *quieres* como yo te quiero cariño) |
te (No me quieres como yo *te* quiero cariño) |
quiero (No me quieres como yo te *quiero* cariño) |
cariño (No me quieres como yo te quiero *cariño*) |`,
  German: `Du (*Du* willst mich nicht so wie ich dich will Baby) |
willst (Du *willst* mich nicht so wie ich dich will Baby) |
nicht (Du willst mich *nicht* so wie ich dich will Baby) |
dich (Du willst mich nicht so wie ich *dich* will Baby) |
Baby (Du willst mich nicht so wie ich dich will *Baby*) |`,
  Arabic: `أنت (*أنت* لا تريدني كما أريدك يا حبيبي) |
لا (أنت *لا* تريدني كما أريدك يا حبيبي) |
تريدني (أنت لا *تريدني* كما أريدك يا حبيبي) |
أريدك (أنت لا تريدني كما *أريدك* يا حبيبي) |
حبيبي (أنت لا تريدني كما أريدك يا *حبيبي*) |`,
  Greek: `Δεν (*Δεν* με θέλεις όπως σε θέλω μωρό μου) |
με (Δεν *με* θέλεις όπως σε θέλω μωρό μου) |
θέλεις (Δεν με *θέλεις* όπως σε θέλω μωρό μου) |
σε (Δεν με θέλεις όπως *σε* θέλω μωρό μου) |
μωρό (Δεν με θέλεις όπως σε θέλω *μωρό* μου) |`,
  Swedish: `Du (*Du* vill inte ha mig som jag vill ha dig älskling) |
vill (Du *vill* inte ha mig som jag vill ha dig älskling) |
inte (Du vill *inte* ha mig som jag vill ha dig älskling) |
dig (Du vill inte ha mig som jag vill ha *dig* älskling) |
älskling (Du vill inte ha mig som jag vill ha dig *älskling*) |`,
};

// Each worked example demonstrates the course's source language translated
// into English, matching the direction used for English-language courses.
export const examples: Record<string, string> = {
  Hebrew: `לא (אתה *לא* רוצה אותי כמו שאני רוצה אותך מותק) | not [adverb]
אתה (*אתה* לא רוצה אותי כמו שאני רוצה אותך מותק) | you [pronoun]
רוצה (אתה לא *רוצה* אותי כמו שאני רוצה אותך מותק) | want [verb]
אותך (אתה לא רוצה אותי כמו שאני רוצה *אותך* מותק) | you [pronoun]
מותק (אתה לא רוצה אותי כמו שאני רוצה אותך *מותק*) | baby [noun]`,
  French: `pas (Tu ne me veux *pas* comme je te veux bébé) | not [adverb]
Tu (*Tu* ne me veux pas comme je te veux bébé) | you [pronoun]
veux (Tu ne me *veux* pas comme je te veux bébé) | want [verb]
te (Tu ne me veux pas comme je *te* veux bébé) | you [pronoun]
bébé (Tu ne me veux pas comme je te veux *bébé*) | baby [noun]`,
  Spanish: `No (*No* me quieres como yo te quiero cariño) | not [adverb]
quieres (No me *quieres* como yo te quiero cariño) | want [verb]
te (No me quieres como yo *te* quiero cariño) | you [pronoun]
quiero (No me quieres como yo te *quiero* cariño) | want [verb]
cariño (No me quieres como yo te quiero *cariño*) | darling [noun]`,
  German: `Du (*Du* willst mich nicht so wie ich dich will Baby) | you [pronoun]
willst (Du *willst* mich nicht so wie ich dich will Baby) | want [verb]
nicht (Du willst mich *nicht* so wie ich dich will Baby) | not [adverb]
dich (Du willst mich nicht so wie ich *dich* will Baby) | you [pronoun]
Baby (Du willst mich nicht so wie ich dich will *Baby*) | baby [noun]`,
  Arabic: `أنت (*أنت* لا تريدني كما أريدك يا حبيبي) | you [pronoun]
لا (أنت *لا* تريدني كما أريدك يا حبيبي) | not [particle]
تريدني (أنت لا *تريدني* كما أريدك يا حبيبي) | want me [verb]
أريدك (أنت لا تريدني كما *أريدك* يا حبيبي) | want you [verb]
حبيبي (أنت لا تريدني كما أريدك يا *حبيبي*) | darling [noun]`,
  Greek: `Δεν (*Δεν* με θέλεις όπως σε θέλω μωρό μου) | not [particle]
με (Δεν *με* θέλεις όπως σε θέλω μωρό μου) | me [pronoun]
θέλεις (Δεν με *θέλεις* όπως σε θέλω μωρό μου) | want [verb]
σε (Δεν με θέλεις όπως *σε* θέλω μωρό μου) | you [pronoun]
μωρό (Δεν με θέλεις όπως σε θέλω *μωρό* μου) | baby [noun]`,
  Swedish: `Du (*Du* vill inte ha mig som jag vill ha dig älskling) | you [pronoun]
vill (Du *vill* inte ha mig som jag vill ha dig älskling) | want to [auxiliary]
inte (Du vill *inte* ha mig som jag vill ha dig älskling) | not [adverb]
dig (Du vill inte ha mig som jag vill ha *dig* älskling) | you [pronoun]
älskling (Du vill inte ha mig som jag vill ha dig *älskling*) | darling [noun]`,
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
    examples[clipLanguage] && translationLanguage === "English"
      ? `## Example Input:
${exampleInputs[clipLanguage]}

## Expected Output:
${examples[clipLanguage]}
`
      : ""
  }

Now translate the following. Output one line per input line, in order:`;
}
