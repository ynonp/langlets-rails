interface CompoundExample {
  input: string;
  output: string[];
}

export function extractCompoundsPrompt(clipLanguage: string): string {
  const example = exampleFor(clipLanguage);
  return `You are choosing learner tokens for a ${clipLanguage} language-learning course.

You will receive the complete transcript, with its existing lesson lines preserved as line breaks.
Rewrite it as a JSON array of learner tokens. Copy all input words in their original order. Most
array items contain one whitespace-separated input word. An item must contain two or more adjacent
words when that occurrence should be learned and translated as one lexical unit, including:

- a lexicalized compound noun
- a conventional office, rank, or occupational title
- an idiom, fixed expression, or phrasal verb
- a multi-word proper name
- another established expression whose separate word translations would be misleading or
  substantially less useful

Do not merely copy the whitespace tokenization: actively identify all such units. In particular,
do not split a conventional title into a role word plus an "of ..." fragment when learners would
normally translate the complete title as one named role. At the same time, do not join an ordinary
description whose meaning is simply the sum of its words.

Decide each occurrence from its complete context. The same written words may be joined in one
occurrence and left separate in another. Never join words across an input line break. Do not omit,
repeat, reorder, respell, or normalize input words. Preserve exact capitalization and punctuation.
Output only the JSON array.

Example input:
${example.input}

Example output:
${JSON.stringify(example.output)}`;
}

export function exampleFor(language: string): CompoundExample {
  const key = language.toLowerCase().split(/[-_]/)[0];
  const iso = LANGUAGE_CODES[key] ?? key;
  return EXAMPLES[iso] ?? EXAMPLES.en;
}

const LANGUAGE_CODES: Record<string, string> = {
  english: "en",
  french: "fr",
  german: "de",
  hebrew: "he",
  russian: "ru",
  spanish: "es",
  arabic: "ar",
};

const EXAMPLES: Record<string, CompoundExample> = {
  en: {
    input: "The chief of staff ate a hot dog beside a hot dog.",
    output: ["The", "chief of staff", "ate", "a", "hot dog", "beside", "a", "hot", "dog."],
  },
  es: {
    input: "El jefe de Estado visitó una casa blanca y después la Casa Blanca.",
    output: [
      "El",
      "jefe de Estado",
      "visitó",
      "una",
      "casa",
      "blanca",
      "y",
      "después",
      "la",
      "Casa Blanca.",
    ],
  },
  fr: {
    input: "Le chef d'état-major visita une maison blanche puis la Maison-Blanche.",
    output: [
      "Le",
      "chef d'état-major",
      "visita",
      "une",
      "maison",
      "blanche",
      "puis",
      "la",
      "Maison-Blanche.",
    ],
  },
  de: {
    input: "Der Vorsitzende des Vorstands besuchte ein weißes Haus und dann das Weiße Haus.",
    output: [
      "Der",
      "Vorsitzende des Vorstands",
      "besuchte",
      "ein",
      "weißes",
      "Haus",
      "und",
      "dann",
      "das",
      "Weiße Haus.",
    ],
  },
  he: {
    input: "ראש הממשלה ביקר בבית לבן ואחר כך בבית הלבן.",
    output: ["ראש הממשלה", "ביקר", "בבית", "לבן", "ואחר", "כך", "בבית הלבן."],
  },
  ru: {
    input: "Начальник штаба посетил белый дом, а затем Белый дом.",
    output: ["Начальник штаба", "посетил", "белый", "дом,", "а", "затем", "Белый дом."],
  },
  ar: {
    input: "قابل رئيس الوزراء وزير الخارجية في بيت أبيض ثم زار البيت الأبيض.",
    output: [
      "قابل",
      "رئيس الوزراء",
      "وزير الخارجية",
      "في",
      "بيت",
      "أبيض",
      "ثم",
      "زار",
      "البيت الأبيض.",
    ],
  },
};
