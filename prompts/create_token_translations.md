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

1. Do not include alignments for auxiliary verbs (e.g., "is", "are", "does") or determiners (e.g., "the") if they don’t have a clear equivalent.

2. Token indices must be continuous (i.e. [2, 3, 4])

3. Token indices should not overlap - that is you can't have more than one "token translation" covering the same word.

{format_instructions}



---

Below are a few examples. Note the languages in the example may differ from the languages in your actual task.

### Example 1

Clip Language: Arabic
Translation Language: English

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
  {{"translation_indices": [1], "clip_indices": [1], "translation_tokens": ["cat"], "clip_tokens": ["قطة"]}},
  {{"translation_indices": [3], "clip_indices": [2], "translation_tokens": ["in"], "clip_tokens": ["في"]}},
  {{"translation_indices": [5], "clip_indices": [4], "translation_tokens": ["house"], "clip_tokens": ["بيت"]}}
]

---

### Example 2

Clip Language: Arabic
Translation Language: English

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
  {{"translation_indices": [1, 2, 3], "clip_indices": [0, 1], "translation_tokens": ["stay", "away", "from"], "clip_tokens": ["أبتعد", "عن"]}},
  {{"translation_indices": [5], "clip_indices": [3], "translation_tokens": ["people"], "clip_tokens": ["ناس"]}},
  {{"translation_indices": [4], "clip_indices": [5], "translation_tokens": ["negative"], "clip_tokens": ["سلبيين"]}}
]

(Note: "I", "ال" were skipped — no strong equivalence)

---

### Example 3

Clip Language: English
Translation Language: Hebrew

English Sentence:
Emancipate yourselves from mental slavery

Hebrew Sentence:
שחררו עצמכם מעבדות מנטלית

English Tokens:
["Emancipate", "yourselves", "from", "mental", "slavery"]

Hebrew Tokens:
["שחררו", "עצמכם", "מעבדות", "מנטלית"]

Output:
[
  {{"translation_indices": [0], "clip_indices": [0], "translation_tokens": ["שחררו"], "clip_tokens": ["Emancipate"]}},
  {{"translation_indices": [1], "clip_indices": [1], "translation_tokens": ["עצמכם"], "clip_tokens": ["yourselves"]}},
  {{"translation_indices": [3], "clip_indices": [3], "translation_tokens": ["מנטלית"], "clip_tokens": ["mental"]}},
  {{"translation_indices": [2], "clip_indices": [4], "translation_tokens": ["מעבדות"], "clip_tokens": ["slavery"]}}
]


---
### Example 4

Clip Language: English
Translation Language: Hebrew

English Sentence:
Sold I to the merchant ships

Hebrew Sentence:
מכרו אותי לספינות הסוחרים

English Tokens:
["Sold", "I", "to", "the", "merchant", "ships"]

Hebrew Tokens:
["מכרו", "אותי", "לספינות", "הסוחרים"]


Output:
[{{"translation_indices"=>[0], "clip_indices"=>[0], "translation_tokens"=>["מכרו"], "clip_tokens"=>["Sold"]}},
 {{"translation_indices"=>[1], "clip_indices"=>[1], "translation_tokens"=>["אותי"], "clip_tokens"=>["I"]}},
 {{"translation_indices"=>[2], "clip_indices"=>[5], "translation_tokens"=>["לספינות"], "clip_tokens"=>["ships"]}},
 {{"translation_indices"=>[3], "clip_indices"=>[4], "translation_tokens"=>["הסוחרים"], "clip_tokens"=>["merchant"]}}]

(Note: while "לספינות" literally means "to the ships", we focus on the noun without the prefix because indices have to be continous and not overlap with other translations)

---


Now align the following sentence pair:

Clip Language: {clip_language}
Translation Language: {translation_language}

{clip_language} Sentence:  
{phrase_text}

{translation_language} Sentence:  
{translation_text}

{clip_language} Tokens:  
{clip_tokens}

{translation_language} Tokens:  
{translation_tokens}

Output:


