# Token Translation Parser Implementation Guide

## Overview

This document provides instructions for implementing a parser that processes LLM responses for creating token translations in a language learning application. The parser converts LLM-generated text into structured data for word-level language alignment.

## Background Context

### What are Token Translations?

Token translations create word-level mappings between languages for educational purposes. They enable granular translation and language learning by mapping specific words or phrases within larger sentences.

**Database Structure:**
- `phrase_id` - Links to a phrase (sentence)
- `l1_start_index`, `l1_end_index` - Word indexes for the source language
- `l2_start_index`, `l2_end_index` - Word indexes for the target language (optional)
- `translation` - The translation text
- `questions` - Array of questions for learning activities
- `similar_sound` - Array of phonetically similar words

### Two Translation Modes

1. **Direct Word Mapping (with L2 indexes):**
   - Maps specific L1 words to specific L2 words
   - Example: "Que" (L1[0..0]) ↔ "That" (L2[0..0])
   - Both L1 and L2 indexes are populated

2. **Custom Translation (without L2 indexes):**
   - Maps L1 words to custom translations not necessarily in the L2 phrase
   - Example: "I was" (L1[0..1]) → "הייתי" (custom translation)
   - L2 indexes remain NULL, allowing flexible translations

## LLM Response Format

The LLM responds with text using `[...]` brackets to indicate token alignments:

### Format Pattern:
```
[Token] in source sentence => [Token] in target sentence or custom translation
Token in [source] sentence => Target sentence with [bracketed] word or custom translation

(Blank line separates phrase groups)
```

### Examples:

**Spanish-English Direct Mapping:**
```
[Pensé] que era un buen momento => [I thought] it was a good time
Pensé que [era] un buen momento => I thought [it was] a good time
Pensé que era un [buen] momento => I thought it was a [good] time
Pensé que era un buen [momento] => moment, time

[Por fin] se hacía realidad => It was [finally] coming true
Por fin [se hacía] realidad => was getting, was becoming # custom translation
```

**English-Hebrew with Custom Translations:**
```
[We were] good, we were gold => [היינו] טובים, היינו זהב
We were [good], we were gold => היינו [טובים], היינו זהב
Kinda dream that [can't] be sold => אי פאשר # custom translation - no L2 mapping
```

**Arabic-English:**
```
[كذبة] وصدقتا => [A lie] and I believed it
كذبة [وصدقتا] => A lie [and I believed it]

[كانت] أكبر كذبة عشتا => [It was] the biggest lie I lived
كانت [أكبر] كذبة عشتا => It was [the biggest] lie I lived
```

## Implementation Tasks

### Step 1: Create Parser Data Structures

Create a new model concern to be included in Phrase that includes the parsing logic.

```ruby
module TokenTranslationBlockParser
  extend ActiveSupport::Concern
  
  def parse(llm_response_block)
  end
end
```

Create a new service object to parse the LLM response

```ruby
class TokenTranslationParser
  def initialize(phrases, llm_response)
  end

  def call
  end
end
```

### Step 2: Implement parse block Logic

1. Implement TokenTranslationBlockParser#parse that gets a block from llm response and returns a list of token translations

2. Example `llm_response_block`:

```
[Pensé] que era un buen momento => [I thought] it was a good time
Pensé que [era] un buen momento => I thought [it was] a good time
Pensé que era un [buen] momento => I thought it was a [good] time
Pensé que era un buen [momento] => moment, time
```

The block matches the phrase that calls #parse

### Step 3: Test concern logic
Use the test data to implement tests for the concern

### Step 4: Implement Parser object
The parser is initialized with a list of phrases and the full LLM response. It uses newlines to match each block to its matching phrase and uses the phrase objects to parse each block.

Example LLM response to parse (2 phrases)

```
[Pensé] que era un buen momento => [I thought] it was a good time
Pensé que [era] un buen momento => I thought [it was] a good time
Pensé que era un [buen] momento => I thought it was a [good] time
Pensé que era un buen [momento] => moment, time

[Por fin] se hacía realidad => It was [finally] coming true
Por fin [se hacía] realidad => was getting, was becoming # custom translation
```

### Step 5: Test full parser
Use test data to test the parser

### Step 6: Handle Edge Cases

Add tests for the edge cases and verify they work. Fix as needed if tests fail.

- **Multi-word tokens:** `[multi word phrase]`
- **Comments:** Text after `#` should be ignored
- **Custom translations:** When only L1 has brackets (L2 indexes = NULL)
- **Special characters:** Apostrophes, punctuation within tokens
- **Language-specific handling:** RTL languages, different scripts

#### Test Data Sources:
- `app/views/prompts/_add_tokens_examples_spanish_english.md.erb`
- `app/views/prompts/_add_tokens_examples_english_hebrew.md.erb`
- `app/views/prompts/_add_tokens_examples_arabic_english.md.erb`
- `app/views/prompts/_add_tokens_examples_french_english.md.erb`

#### Required Test Cases:

1. **Basic Parsing:**
   - Correct number of phrases parsed
   - L1/L2 text extraction
   - Token translation count per phrase

2. **Word Index Mapping:**
   - Single word tokens: `[word]` → correct start/end indexes
   - Multi-word tokens: `[multi word]` → consecutive indexes
   - L2 mapping: Both L1 and L2 brackets → both index sets populated

3. **Custom Translations:**
   - L1 bracket only → L2 indexes should be NULL
   - Translation text stored correctly
   - Comments ignored

4. **Edge Cases:**
   - Apostrophes: `'til`, contractions
   - Punctuation within tokens
   - Empty lines between phrase groups
   - Malformed input handling

## Error Handling

- Gracefully handle malformed input
- Log parsing errors without crashing
- Skip invalid lines while processing valid ones
- Provide meaningful error messages for debugging
- It's ok to skip a token or a line, but if you find a line mismatch (text doesn't match the phrase) raise an exception

## Success Criteria

- All example data from prompt files parses correctly
- Generated token translations match expected word alignments
- Both direct mapping and custom translation modes work
- Comprehensive test coverage with meaningful assertions
- Clean, maintainable code following Rails conventions
