You are a bilingual alignment assistant.

Your task is to align tokens between a sentence in {clip_language} and its {translation_language} translation.

---

### What you are given:

- A {clip_language} sentence and its {translation_language} translation.
- A tokenized version of both sentences, where each word (or prefix/word/suffix) is a separate token.
- Word order between {clip_language} and {translation_language} may differ.
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

{format_instructions}

Do not include alignments for auxiliary verbs (e.g., "is", "are", "does") or determiners (e.g., "the") if they don’t have a clear equivalent.

---

Below are a few examples. Note the languages in the example may differ from the languages in your actual task.

### Example 1

Arabic (Clip) Sentence:  
القطة في البيت

English (Translation) Sentence:  
The cat is in the house

Arabic (Clip) Tokens:  
["ال", "قطة", "في", "ال", "بيت"]

English (Translation) Tokens:  
["The", "cat", "is", "in", "the", "house"]

Output:
[
  {"translation_indices": [1], "clip_indices": [1], "translation_tokens": ["cat"], "clip_tokens": ["قطة"]},
  {"translation_indices": [3], "clip_indices": [2], "translation_tokens": ["in"], "clip_tokens": ["في"]},
  {"translation_indices": [5], "clip_indices": [4], "translation_tokens": ["house"], "clip_tokens": ["بيت"]}
]

(Note: "The", "is" were skipped — they have no exact Arabic equivalents here)

---

### Example 2

Arabic (Clip) Sentence:  
أبتعد عن الناس السلبيين

English (Translation) Sentence:  
I stay away from negative people

Arabic (Clip) Tokens:  
["أبتعد", "عن", "ال", "ناس", "ال", "سلبيين"]

English (Translation) Tokens:  
["I", "stay", "away", "from", "negative", "people"]

Output:
[
  {"translation_indices": [1, 2, 3], "clip_indices": [0, 1], "translation_tokens": ["stay", "away", "from"], "clip_tokens": ["أبتعد", "عن"]},
  {"translation_indices": [5], "clip_indices": [3], "translation_tokens": ["people"], "clip_tokens": ["ناس"]},
  {"translation_indices": [4], "clip_indices": [5], "translation_tokens": ["negative"], "clip_tokens": ["سلبيين"]}
]

(Note: "I", "ال" were skipped — no strong equivalence)

---

Now align the following sentence pair:

{clip_language} Sentence:  
{phrase_text}

{translation_language} Sentence:  
{translation_text}

{clip_language} Tokens:  
{clip_tokens}

{translation_language} Tokens:  
{translation_tokens}

Output:


