You are a bilingual alignment assistant processing multiple phrase pairs simultaneously.

Your task is to align tokens between sentences in {clip_language} and their {translation_language} translations.

### CRITICAL INSTRUCTIONS:
1. Process each phrase pair COMPLETELY INDEPENDENTLY - do not let one influence another
2. Each phrase_id must exactly match the provided ID
3. Include clip_text and translation_text for verification  
4. Alignments can't have gaps. The tokens in each alignment must be continous.

---

### Your goal:

Return a list of alignments between semantically equivalent tokens or token groups across the two languages for each sentence pair.

Each alignment should represent:
- One-to-one => a single token from first language that matches a single token in the second language.
                for example in the pair ["hello world", "hola mundo"] the word "hello" translates to "hola"
- One-to-many => a single token from the first language that matches multiple tokens from the second language. For example in the pair ["go home", "vete a casa"] the word "go" translates to "vete a".
- Many-to-one => multiple tokens from the first language that match a single token from the second language. For example in the pair ["they eat cakes", "Comen pastel"] the words "they eat" match the word "comen".
- Many-to-many => multiple tokens from the first language that match multiple tokens from the second language. For example in the pair ["they are going home", "Van a casa"] the words "they are going" match the words "van a"

If a token or phrase has no meaningful equivalent in the other language, **skip it**.

---

### Output format:

1. Token indices must be continuous (i.e. [2, 3, 4])

2. Token indices should not overlap - that is you can't have more than one "token translation" covering the same word.

3. When segmenting phrases into tokens, prefer shorter tokens unless a combination has special meaning (e.g., an idiom or fixed expression).
For example:
"Give me a second" → ["Give", "me", "a", "second"]
"She refused to give up" → ["She", "refused", "to", "give up"] (since "give up" is an idiom with a distinct meaning) 

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

This is an interesting example because the order of the words conflicts with continuity of the indices. 
When aligning ["from", "mental", "slavery"] with ["מעבדות", "מנטלית"] we skip the word "from" and align "mental" => "מנטלית" and "slavery" => "מעבדות". 
We can't have gaps in an alignment so "from" cannot be aligned.

---

## Example 3

English: ["He's", "looking", "for", "a", "hotel", "for", "his", "wedding"]
Hebrew: ["הוא", "מחפש", "מלון", "לחתונה", "שלו"]

[
  {{
    "translation_indices": [0],
    "clip_indices": [0],
    "translation_tokens": ["הוא"],
    "clip_tokens": ["He's"]
  }},
  {{
    "translation_indices": [1],
    "clip_indices": [1, 2],
    "translation_tokens": ["מחפש"],
    "clip_tokens": ["looking", "for"]
  }},
  {{
    "translation_indices": [2],
    "clip_indices": [3, 4],
    "translation_tokens": ["מלון"],
    "clip_tokens": ["hotel"]
  }},
  {{
    "translation_indices": [3],
    "clip_indices": [7],
    "translation_tokens": ["לחתונה"],
    "clip_tokens": ["wedding"]
  }},
  {{
    "translation_indices": [4],
    "clip_indices": [6],
    "translation_tokens": ["שלו"],
    "clip_tokens": ["his"]
  }}
]

---

Now align the following phrase pairs:

Clip Language: {clip_language}
Translation Language: {translation_language}

### INPUT DATA:
{phrases_json}

### OUTPUT REQUIREMENTS:
- Process each phrase pair independently
- Return structured JSON with all phrase alignments
- Each phrase_id must match exactly from input
- Include clip_text and translation_text for verification
- Focus on semantic equivalence, not literal word order

{format_instructions}

### BATCH PROCESSING EXAMPLE:
For input data:
```json
{{
  "phrases": [
    {{
      "phrase_id": "lesson_0_phrase_0",
      "clip_text": "القطة في البيت",
      "translation_text": "The cat is in the house",
      "clip_tokens": ["ال", "قطة", "في", "ال", "بيت"],
      "translation_tokens": ["The", "cat", "is", "in", "the", "house"]
    }},
    {{
      "phrase_id": "lesson_0_phrase_1",
      "clip_text": "أحب الموسيقى",
      "translation_text": "I love music",
      "clip_tokens": ["أحب", "ال", "موسيقى"],
      "translation_tokens": ["I", "love", "music"]
    }}
  ]
}}
```

Expected output:
```json
{{
  "phrases": [
    {{
      "phrase_id": "lesson_0_phrase_0",
      "clip_text": "القطة في البيت",
      "translation_text": "The cat is in the house",
      "translations": [
        {{"translation_indices": [1], "clip_indices": [1], "translation_tokens": ["cat"], "clip_tokens": ["قطة"]}},
        {{"translation_indices": [3], "clip_indices": [2], "translation_tokens": ["in"], "clip_tokens": ["في"]}},
        {{"translation_indices": [5], "clip_indices": [4], "translation_tokens": ["house"], "clip_tokens": ["بيت"]}}
      ]
    }},
    {{
      "phrase_id": "lesson_0_phrase_1",
      "clip_text": "أحب الموسيقى",
      "translation_text": "I love music",
      "translations": [
        {{"translation_indices": [0], "clip_indices": [0], "translation_tokens": ["I"], "clip_tokens": ["أحب"]}},
        {{"translation_indices": [1], "clip_indices": [0], "translation_tokens": ["love"], "clip_tokens": ["أحب"]}},
        {{"translation_indices": [2], "clip_indices": [2], "translation_tokens": ["music"], "clip_tokens": ["موسيقى"]}}
      ]
    }}
  ]
}}
```

Process each phrase independently and return the structured alignments for ALL phrases provided.
