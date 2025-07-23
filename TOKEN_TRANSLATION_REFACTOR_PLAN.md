# TokenTranslation Refactor: Character Index to Word Index Migration

## Issue Overview

**Current State**: TokenTranslation model uses character-based indexes (`l1_start_index`, `l1_end_index`, `l2_start_index`, `l2_end_index`) to identify word/token positions within phrases.

**Wanted State**: TokenTranslation model should use word-based indexes instead of character-based indexes for more precise and consistent token identification.

**Business Impact**: This change will improve:
- Accuracy of word-level language learning activities 
- Consistency between AI-generated alignments and user interface
- Performance of token matching algorithms
- Maintainability of tokenization logic

## Technical Analysis

### Current Character-Based System

The current implementation uses character offsets to identify token boundaries:

```ruby
# Current TokenTranslation fields
l1_start_index: 15  # Character position where token starts in phrase.text_l1
l1_end_index: 20    # Character position where token ends in phrase.text_l1 
l2_start_index: 12  # Character position where token starts in phrase.text_l2
l2_end_index: 17    # Character position where token ends in phrase.text_l2

# Used to extract text like:
def original_text
  phrase.text_l1[l1_start_index...l1_end_index]
end
```

### Target Word-Based System

The new implementation will use word indexes based on the provided tokenization function:

```ruby
def tokenize(text)
  text.scan(/\p{L}+(?:'\p{L}+)*/u)
end

# New TokenTranslation semantics
l1_start_index: 2   # Index of first word in the token translation (0-based)
l1_end_index: 3     # Index of last word in the token translation (0-based, inclusive)
l2_start_index: 3   # Index of first word in L2 translation (optional)
l2_end_index: 4     # Index of last word in L2 translation (optional)
```

### Key Constraints

1. **Continuous word indexes required**: If a TokenTranslation has non-continuous word indexes, skip creating it
2. **L2 indexes are optional**: Can be nil if no L2 alignment exists
3. **Ignore existing data**: Assume database is empty for migration purposes
4. **Use juanes.json as test data**: Import and validate against this dataset

## Implementation Plan

### Phase 2: Model Updates

#### 2.1 Update TokenTranslation Model
```ruby
# app/models/token_translation.rb
class TokenTranslation < ApplicationRecord
  include AzureTextToSpeech
  
  belongs_to :phrase
  has_one_attached :l1_audio, service: :s3_public

  # Generate audio when token is created
  after_create :generate_l1_audio, if: :should_generate_audio?
  
  # Regenerate audio when indices change (affecting the original_text)
  after_update :generate_l1_audio, if: :should_generate_audio_on_update?

  scope :with_questions, ->() {
    where("questions is not null and cardinality(questions) > 0")
  }

  # NEW: Extract original text using word indexes
  def original_text
    l1_words = tokenize(phrase.text_l1)
    return "" if l1_start_index.nil? || l1_end_index.nil?
    return "" if l1_start_index < 0 || l1_end_index >= l1_words.length
    return "" if l1_start_index > l1_end_index

    l1_words[l1_start_index..l1_end_index].join(' ')
  end

  # NEW: Extract L2 text using word indexes
  def translation_text
    return translation if l2_start_index.nil? || l2_end_index.nil?
    
    l2_words = tokenize(phrase.text_l2)
    return translation if l2_start_index < 0 || l2_end_index >= l2_words.length
    return translation if l2_start_index > l2_end_index

    l2_words[l2_start_index..l2_end_index].join(' ')
  end

  # NEW: Validation for continuous word indexes
  validate :validate_continuous_word_indexes

  private

  def tokenize(text)
    text.scan(/\p{L}+(?:'\p{L}+)*/u)
  end

  def validate_continuous_word_indexes
    # Validate L1 indexes
    if l1_start_index.present? && l1_end_index.present?
      if l1_start_index > l1_end_index
        errors.add(:l1_start_index, "must be less than or equal to l1_end_index")
      end

      l1_words = tokenize(phrase.text_l1)
      if l1_start_index < 0 || l1_end_index >= l1_words.length
        errors.add(:l1_start_index, "word indexes out of bounds")
      end
    end

    # Validate L2 indexes (optional)
    if l2_start_index.present? && l2_end_index.present?
      if l2_start_index > l2_end_index
        errors.add(:l2_start_index, "must be less than or equal to l2_end_index")
      end

      l2_words = tokenize(phrase.text_l2)
      if l2_start_index < 0 || l2_end_index >= l2_words.length
        errors.add(:l2_start_index, "word indexes out of bounds")
      end
    end
  end

  def should_generate_audio?
    # Generate audio if we have text and a language
    original_text.present? && phrase&.l1&.iso_name.present?
  end

  def should_generate_audio_on_update?
    # Generate audio if indices changed (which affects original_text) and we have the necessary data
    (saved_change_to_l1_start_index? || saved_change_to_l1_end_index?) && should_generate_audio?
  end

  def generate_l1_audio
    # Queue background job for audio generation
    GenerateTokenAudioJob.perform_later(id)
  end
end
```

#### 2.2 Update Phrase Model
```ruby
# app/models/phrase.rb - Update add_token_translation method
class Phrase < ApplicationRecord
  # ... existing code ...

  def add_token_translation(text, text_occurrence, translation, translation_occurrence, **attributes)
    l1_words = tokenize(text_l1)
    l2_words = tokenize(text_l2)
    
    # Find word indexes for L1 text
    l1_word_indexes = find_word_indexes(l1_words, text, text_occurrence)
    if l1_word_indexes.nil?
      Rails.logger.error("Couldn't find text '#{text}' occurrence #{text_occurrence} in L1 phrase: #{text_l1}")
      return nil
    end

    # Find word indexes for L2 text (optional)
    l2_word_indexes = nil
    if translation_occurrence >= 0 && translation.present?
      l2_word_indexes = find_word_indexes(l2_words, translation, translation_occurrence)
      if l2_word_indexes.nil?
        Rails.logger.warn("Couldn't find translation '#{translation}' occurrence #{translation_occurrence} in L2 phrase: #{text_l2}")
      end
    end

    # Validate continuous indexes
    unless continuous_indexes?(l1_word_indexes)
      Rails.logger.error("Non-continuous L1 word indexes for '#{text}'. Skipping token translation.")
      return nil
    end

    if l2_word_indexes && !continuous_indexes?(l2_word_indexes)
      Rails.logger.error("Non-continuous L2 word indexes for '#{translation}'. Skipping token translation.")
      return nil
    end

    begin
      TokenTranslation.create!(
        phrase: self,
        l1_start_index: l1_word_indexes.first,
        l1_end_index: l1_word_indexes.last,
        l2_start_index: l2_word_indexes&.first,
        l2_end_index: l2_word_indexes&.last,
        translation: translation,
        **attributes
      )
    rescue ActiveRecord::RecordNotUnique => e
      Rails.logger.error("Duplicate token translation for phrase #{self.id}. Skipping. Error: #{e.message}")
      return nil
    end
  end

  def find_token_translation(text, text_index=0)
    l1_words = tokenize(text_l1)
    target_word_indexes = find_word_indexes(l1_words, text, text_index)
    return nil if target_word_indexes.nil?

    result = self.token_translations.find_by(
      l1_start_index: target_word_indexes.first,
      l1_end_index: target_word_indexes.last
    )
    
    if result.nil?
      Rails.logger.debug("No token translation found for '#{text}' at word indexes #{target_word_indexes}")
    end
    
    result
  end

  private

  def tokenize(text)
    text.scan(/\p{L}+(?:'\p{L}+)*/u)
  end

  def find_word_indexes(words, target_text, occurrence)
    target_words = tokenize(target_text)
    return nil if target_words.empty?

    occurrences_found = 0
    
    (0..words.length - target_words.length).each do |start_idx|
      if words[start_idx, target_words.length] == target_words
        if occurrences_found == occurrence
          return (start_idx..start_idx + target_words.length - 1).to_a
        end
        occurrences_found += 1
      end
    end

    nil
  end

  def continuous_indexes?(indexes)
    return false if indexes.nil? || indexes.empty?
    indexes.each_cons(2).all? { |a, b| b == a + 1 }
  end
end
```

### Phase 3: Update AI/Create Song Service
This service is deprecated and there's no need to update it

### Phase 4: View Updates

#### 4.1 Update Language Alignment Activity View
```erb
<!-- app/views/activities/_language_alignment_activity.html.erb -->
<%
  # Build phrases with token information using word indexes
  phrases_with_all_tokens = activity.phrases.map.with_index do |phrase, phrase_index|
    l1_words = phrase.text_l1.scan(/\p{L}+(?:'\p{L}+)*/u)
    l2_words = phrase.text_l2.scan(/\p{L}+(?:'\p{L}+)*/u)
    
    tokens = phrase.token_translations.map do |token|
      {
        l1_start_index: token.l1_start_index,
        l1_end_index: token.l1_end_index,
        l2_start_index: token.l2_start_index,
        l2_end_index: token.l2_end_index,
        translation: token.translation,
        audio_url: token.l1_audio.present? ? rails_blob_path(token.l1_audio, only_path: true) : nil,
        original_text: token.original_text
      }
    end

    {
      original_text: phrase.text_l1,
      translated_text: phrase.text_l2,
      l1_words: l1_words,
      l2_words: l2_words,
      tokens: tokens
    }
  end
%>

<!-- Update rendering logic to use word-based segments -->
<% phrases_with_all_tokens.each_with_index do |phrase, phrase_index| %>
  <div class="original-phrase" data-phrase-id="<%= phrase_index %>">
    <% 
      # Create segments based on word boundaries
      segments = []
      current_word_index = 0
      
      phrase[:l1_words].each_with_index do |word, word_index|
        # Check if this word is part of a token translation
        token = phrase[:tokens].find { |t| 
          t[:l1_start_index] <= word_index && word_index <= t[:l1_end_index] 
        }
        
        if token && word_index == token[:l1_start_index]
          # Start of a token - get all words in this token
          token_words = phrase[:l1_words][token[:l1_start_index]..token[:l1_end_index]]
          segments << {
            text: token_words.join(' '),
            token: token,
            word_indexes: (token[:l1_start_index]..token[:l1_end_index]).to_a
          }
        elsif !token
          # Regular word, not part of any token
          segments << { text: word, token: nil, word_indexes: [word_index] }
        end
      end
    %>
    
    <% segments.each do |segment| %>
      <% if segment[:token] %>
        <span class="token-segment clickable" 
              data-token-audio="<%= segment[:token][:audio_url] %>"
              data-word-indexes="<%= segment[:word_indexes].join(',') %>">
          <%= segment[:text] %>
        </span>
      <% else %>
        <span class="regular-text"><%= segment[:text] %></span>
      <% end %>
      <span class="word-separator"> </span>
    <% end %>
  </div>
<% end %>
```

### Phase 5: Testing Updates

#### 5.1 Update TokenTranslation Tests
```ruby
# test/models/token_translation_test.rb
class TokenTranslationTest < ActiveSupport::TestCase
  def setup
    @l1_language = languages(:spanish)
    @l2_language = languages(:english)
    @medium = media(:test_video)
    @phrase = Phrase.create!(
      text_l1: "Hola mundo hermoso",  # Words: ["Hola", "mundo", "hermoso"]
      text_l2: "Hello beautiful world",  # Words: ["Hello", "beautiful", "world"]
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
  end

  test "should extract correct original_text using word indexes" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 1,  # "mundo"
      l1_end_index: 1,
      l2_start_index: 2,  # "world"
      l2_end_index: 2,
      translation: "world"
    )
    
    assert_equal "mundo", token_translation.original_text
  end

  test "should extract multi-word original_text using word indexes" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 1,  # "mundo hermoso" 
      l1_end_index: 2,
      l2_start_index: 1,  # "beautiful world"
      l2_end_index: 2,
      translation: "beautiful world"
    )
    
    assert_equal "mundo hermoso", token_translation.original_text
    assert_equal "beautiful world", token_translation.translation_text
  end

  test "should validate continuous word indexes" do
    # Non-continuous indexes should be invalid
    token_translation = TokenTranslation.new(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 2,  # Skips word index 1
      translation: "invalid"
    )
    
    assert_not token_translation.valid?
    assert_includes token_translation.errors[:l1_start_index], "word indexes out of bounds"
  end

  test "should handle missing L2 indexes gracefully" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: nil,
      l2_end_index: nil,
      translation: "hello"
    )
    
    assert_equal "Hola", token_translation.original_text
    assert_equal "hello", token_translation.translation_text  # Falls back to translation field
  end

  test "should queue l1_audio generation on word index change" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "hello"
    )
    
    assert_enqueued_jobs 1, only: GenerateTokenAudioJob do
      token_translation.update!(l1_start_index: 1, l1_end_index: 1)
    end
  end
end
```

#### 5.2 Update Phrase Model Tests
```ruby
# test/models/phrase_test.rb - Add word-based tests
class PhraseTest < ActiveSupport::TestCase
  test "add_token_translation should use word indexes" do
    phrase = phrases(:sample_phrase)  # "Hello beautiful world" / "Hola mundo hermoso"
    
    token = phrase.add_token_translation("beautiful", 0, "hermoso", 0)
    
    assert_not_nil token
    assert_equal 1, token.l1_start_index  # "beautiful" is word index 1
    assert_equal 1, token.l1_end_index
    assert_equal 2, token.l2_start_index  # "hermoso" is word index 2  
    assert_equal 2, token.l2_end_index
  end

  test "add_token_translation should handle multi-word phrases" do
    phrase = phrases(:sample_phrase)
    
    token = phrase.add_token_translation("beautiful world", 0, "mundo hermoso", 0)
    
    assert_not_nil token
    assert_equal 1, token.l1_start_index  # "beautiful world" starts at word 1
    assert_equal 2, token.l1_end_index    # ends at word 2
    assert_equal 1, token.l2_start_index  # "mundo hermoso" starts at word 1
    assert_equal 2, token.l2_end_index    # ends at word 2
  end

  test "should skip non-continuous word translations" do
    # This test would require a phrase where words don't align continuously
    # Implementation would depend on specific test data
  end
end
```

## Rollout Plan

### Step 1: Preparation
1. Create feature branch: `feature/word-based-token-indexes`
2. Run existing tests to establish baseline
3. Create backup plan for any data rollback needs

### Step 2: Implementation 
1. Create and run database migration - No need. Database doesn't change
2. Update TokenTranslation model with new logic
3. Update Phrase model methods
4. Refactor Ai::CreateSong service
5. Update view templates
6. Run comprehensive test suite

### Step 3: Testing
1. Unit tests for all model changes
2. Integration tests for AI service
3. Import juanes.json data and validate
4. Manual testing of language alignment activities
5. Performance testing with larger datasets

### Step 4: Deployment
1. Deploy to staging environment
2. Run full import test with juanes.json
3. Validate all learning activities work correctly
4. Deploy to production with monitoring

## Validation Criteria

✅ **TokenTranslation.original_text** returns correct word-based text extraction  
✅ **Multi-word tokens** are handled correctly with continuous word indexes  
✅ **Non-continuous word indexes** are properly rejected during creation  
✅ **L2 indexes are optional** and can be nil without breaking functionality  
✅ **Audio generation** still works with new word-based original_text method  
✅ **Language alignment activities** display correctly with word-based segments  
✅ **Juanes.json data** imports successfully using new word index system  
✅ **AI service** creates TokenTranslations with word indexes instead of character indexes  
✅ **Performance** is maintained or improved compared to character-based system  

## Risks and Mitigation

**Risk**: Audio generation breaks due to original_text changes  
**Mitigation**: Extensive testing of audio callbacks and regeneration logic

**Risk**: View rendering breaks with word-based segments  
**Mitigation**: Update all view logic to use word boundaries, test thoroughly

**Risk**: Import scripts fail with edge cases  
**Mitigation**: Robust error handling and validation in import logic

**Risk**: Performance degradation with word tokenization  
**Mitigation**: Consider caching tokenized words if performance issues arise

## Success Metrics

- All existing tests pass with new word-based implementation
- Juanes.json imports completely without skipped translations
- Language alignment activities render correctly
- Audio generation continues to work seamlessly  
- No performance regression in token matching activities
- Clear improvement in word-level accuracy for language learning exercises
