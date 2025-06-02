import type { 
  ScriptConfig, 
  PhraseData, 
  LessonPhrase,
  LessonWithTokens
} from '../create_song.ts';

// Prompt generation function types
export type LessonGenerationPromptFn = (config: ScriptConfig, songName: string, phrases: PhraseData[]) => string;

export type TokenTranslationPromptFn = (config: ScriptConfig, phraseText: string, translationText: string, fullLyrics: string) => string;

export type LessonActivityPromptFn = (config: ScriptConfig, lesson: LessonWithTokens, fullLyrics: string) => string;

export type ListenActivityTokenSelectionPromptFn = (config: ScriptConfig, phrases: LessonPhrase[]) => string;

export type LanguageAlignmentTokenSelectionPromptFn = (config: ScriptConfig, phrases: LessonPhrase[]) => string;

export type PromptsForLanguages = {
  getLessonGenerationPrompt: LessonGenerationPromptFn,
  getTokenTranslationPrompt: TokenTranslationPromptFn,
  getLessonActivityPrompt: LessonActivityPromptFn,
  getListenActivityTokenSelectionPrompt: ListenActivityTokenSelectionPromptFn,
  getLanguageAlignmentTokenSelectionPrompt: LanguageAlignmentTokenSelectionPromptFn
}

export function getPromptsForLanguages(clipLanguage: string, translationLanguage: string): PromptsForLanguages {
  return {
    getLessonGenerationPrompt: (config: ScriptConfig, songName: string, phrases: PhraseData[]) => {
      return `
  You are a ${clipLanguage} teacher teaching ${translationLanguage} speaking students, and you're given access to a new course creation platform. Your task is to use the platform and create a language lesson on the song ${songName}.
  Start by outlining the lessons for the song, so each lesson corresponds to a subsequent part of the song (for example "intro", "verse 1", "chorus", "outro").
  Each lesson should include roughly between 4 and 8 phrases, in a division that makes sense educationally and semantically.
  
  Also as the lessons are part of a language course, if the same part of the song repeats itself for example if the chorus is sang twice you need to create just one lesson for it.

  Return a list of lesson names

  Below are the song lyrics arranged in phrases:
  ${JSON.stringify(phrases)}
  `;
    },

    getTokenTranslationPrompt: (config: ScriptConfig, phraseText: string, translationText: string, fullLyrics: string) => {
      const clipLanguage = config.languageConfig.clipLanguage.name;
      const translationLanguage = config.languageConfig.translationLanguage.name
      const clipTokens = phraseText.split(/\P{L}/u).filter(l => l.length > 0);
      const translationTokens = translationText.split(/\P{L}/u).filter(l => l.length > 0);

      return `
You are a bilingual alignment assistant.

Your task is to align tokens between a sentence in ${clipLanguage} and its ${translationLanguage} translation.

---

### What you are given:

- A ${clipLanguage} sentence and its ${translationLanguage} translation.
- A tokenized version of both sentences, where each word (or prefix/word/suffix) is a separate token.
- Word order between ${clipLanguage} and ${translationLanguage} may differ.
- Some words (especially auxiliary verbs like "is", "are", or definite articles like "the") may not have a direct equivalent in the other language.

---

### Your goal:

Return a list of alignments between semantically equivalent tokens or token groups across the two languages.

Each alignment should represent:
- One-to-one
- One-to-many
- Many-to-one
- Many-to-many

If a token or phrase has no meaningful equivalent in the other language, **skip it**.

---

### Output format:

Return a JSON array. Each alignment is an object containing:

- \`"clip_indices"\`: list of indices in the ${clipLanguage} token array
- \`"translation_indices"\`: list of indices in the ${translationLanguage} token array
- \`"clip_tokens"\`: list of the corresponding ${clipLanguage} tokens
- \`"translation_tokens"\`: list of the corresponding ${translationLanguage} tokens
- \`"clip_similar_sound"\`: list of possible words in ${clipLanguage} that have similar sound but different meaning (used in listening comprehension activities as distractors)

Do not include alignments for auxiliary verbs (e.g., "is", "are", "does") or determiners (e.g., "the") if they don’t have a clear equivalent.

---

### Example 1

Arabic Sentence:  
القطة في البيت

English Sentence:  
The cat is in the house

Arabic Tokens:  
["ال", "قطة", "في", "ال", "بيت"]

English Tokens:  
["The", "cat", "is", "in", "the", "house"]

Output:
[
  {"en_indices": [1], "ar_indices": [1], "en_tokens": ["cat"], "ar_tokens": ["قطة"]},
  {"en_indices": [3], "ar_indices": [2], "en_tokens": ["in"], "ar_tokens": ["في"]},
  {"en_indices": [5], "ar_indices": [4], "en_tokens": ["house"], "ar_tokens": ["بيت"]}
]

(Note: "The", "is" were skipped — they have no exact Arabic equivalents here)

---

### Example 2

Arabic Sentence:  
أبتعد عن الناس السلبيين

English Sentence:  
I stay away from negative people

Arabic Tokens:  
["أبتعد", "عن", "ال", "ناس", "ال", "سلبيين"]

English Tokens:  
["I", "stay", "away", "from", "negative", "people"]

Output:
[
  {"en_indices": [1, 2, 3], "ar_indices": [0, 1], "en_tokens": ["stay", "away", "from"], "ar_tokens": ["أبتعد", "عن"]},
  {"en_indices": [5], "ar_indices": [3], "en_tokens": ["people"], "ar_tokens": ["ناس"]},
  {"en_indices": [4], "ar_indices": [5], "en_tokens": ["negative"], "ar_tokens": ["سلبيين"]}
]

(Note: "I", "ال" were skipped — no strong equivalence)

---

Now align the following sentence pair:

${clipLanguage} Sentence:  
${phraseText}

${translationLanguage} Sentence:  
${translationText}

${clipLanguage} Tokens:  
${clipTokens}

${translationLanguage} Tokens:  
${translationTokens}

Output:

    `;
    },

    getLessonActivityPrompt: (config: ScriptConfig, lesson: LessonWithTokens, fullLyrics: string) => {
      return `
  Create a lesson activity template from the lesson data for ${clipLanguage} learners who speak ${translationLanguage}. 
  The order of the output array is the order of activities. Use the default template:
      ${JSON.stringify(lesson)}

    For context the full lyrics of the song are:
      ${fullLyrics}
    `;
    },

    getListenActivityTokenSelectionPrompt: (config: ScriptConfig, phrases: LessonPhrase[]) => {
      return `
  Select the token translations for a ListenActivity from the following list of phrases.
  This activity helps ${translationLanguage} speakers practice listening to ${clipLanguage}:
      ${JSON.stringify(phrases)}

  In the listening activity a user listens to the song and needs to identify words (token translations) from the song.
  Your task is to select the words or expressions (called tokens) that the user needs to identify.
  For each phrase, which is a line from the song, you need to select just 1-2 words. 
  Remember you don't want to burden the user with too many words to identify.  
    `;
    },

    getLanguageAlignmentTokenSelectionPrompt: (config: ScriptConfig, phrases: LessonPhrase[]) => {
      return `
  Select the token translations for a LanguageAlignment activity from the following list of phrases.
  This activity helps ${translationLanguage} speakers align ${clipLanguage} words with their translations:
      ${JSON.stringify(phrases)}

  In the language alignment activity a user sees a phrase in their own language with some words "marked" and they need to find the corresponding words from the song.  
  Your task is to select the words or expressions (called tokens) that the user needs to identify.
  For each phrase, which is a line from the song, you need to select just 1-2 words. 
  Remember you don't want to burden the user with too many words to identify.
    `;
    }
  };
}