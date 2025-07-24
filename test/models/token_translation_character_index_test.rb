require "test_helper"

class TokenTranslationCharacterIndexTest < ActiveSupport::TestCase
  def setup
    # Create test languages
    @l1_language = Language.create!(
      iso_name: 'en',
      english_name: 'English',
      native_name: 'English'
    )
    
    @l2_language = Language.create!(
      iso_name: 'es', 
      english_name: 'Spanish',
      native_name: 'Español'
    )
    
    # Create test medium
    @medium = Medium.create!(
      url: 'https://example.com'
    )
  end

  test "l1_start_character_index should return correct character position for single word" do
    phrase = Phrase.create!(
      text_l1: "Hello beautiful world",  # Words: ["Hello", "beautiful", "world"]
      text_l2: "Hola mundo hermoso",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 1,  # "beautiful"
      l1_end_index: 1,
      translation: "hermoso"
    )
    
    # "beautiful" starts at character index 6 (after "Hello ")
    assert_equal 6, token_translation.l1_start_character_index
  end

  test "l1_end_character_index should return correct character position for single word" do
    phrase = Phrase.create!(
      text_l1: "Hello beautiful world",  # Words: ["Hello", "beautiful", "world"]
      text_l2: "Hola mundo hermoso",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 1,  # "beautiful"
      l1_end_index: 1,
      translation: "hermoso"
    )
    
    assert_equal 15, token_translation.l1_end_character_index
  end

  test "l1_character_indices should work for multi-word tokens" do
    phrase = Phrase.create!(
      text_l1: "Hello beautiful world",
      text_l2: "Hola mundo hermoso",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 0,  # "Hello beautiful" (words 0 and 1)
      l1_end_index: 1,
      translation: "Hola hermoso"
    )
    
    assert_equal 0, token_translation.l1_start_character_index
    assert_equal 15, token_translation.l1_end_character_index
  end

  test "l2_character_indices should work correctly" do
    phrase = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo hermoso",  # Words: ["Hola", "mundo", "hermoso"]
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 1,  # "mundo"
      l2_end_index: 1,
      translation: "world"
    )
    
    assert_equal 5, token_translation.l2_start_character_index
    assert_equal 10, token_translation.l2_end_character_index
  end

  test "should handle word appearing multiple times - first occurrence" do
    phrase = Phrase.create!(
      text_l1: "The cat and the dog",  # Words: ["The", "cat", "and", "the", "dog"]
      text_l2: "El gato y el perro",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 0,  # First "The"
      l1_end_index: 0,
      translation: "El"
    )
    
    assert_equal 0, token_translation.l1_start_character_index
    assert_equal 3, token_translation.l1_end_character_index
  end

  test "should handle word appearing multiple times - second occurrence" do
    phrase = Phrase.create!(
      text_l1: "The cat and the dog",  # Words: ["The", "cat", "and", "the", "dog"]
      text_l2: "El gato y el perro",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 3,  # Second "the" (lowercase)
      l1_end_index: 3,
      translation: "el"
    )
    
    assert_equal 12, token_translation.l1_start_character_index
    assert_equal 15, token_translation.l1_end_character_index
  end

  test "should handle contractions" do
    phrase = Phrase.create!(
      text_l1: "I don't like it",  # Words: ["I", "don't", "like", "it"]
      text_l2: "No me gusta",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 1,  # "don't"
      l1_end_index: 1,
      translation: "No"
    )
    
    assert_equal 2, token_translation.l1_start_character_index
    assert_equal 7, token_translation.l1_end_character_index
  end

  test "should handle word that appears as part of another word" do
    phrase = Phrase.create!(
      text_l1: "I saw a cat in the catalog",  # Words: ["I", "saw", "a", "cat", "in", "the", "catalog"]
      text_l2: "Vi un gato en el catálogo",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 3,  # "cat" (should not match "catalog")
      l1_end_index: 3,
      translation: "gato"
    )
    
    # "cat" (the standalone word) starts at character index 8 (after "I saw a ")
    assert_equal 8, token_translation.l1_start_character_index
    assert_equal 11, token_translation.l1_end_character_index
  end

  test "should return nil for out of bounds indices" do
    phrase = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 10,  # Out of bounds
      l1_end_index: 10,
      translation: "test"
    )
    
    assert_nil token_translation.l1_start_character_index
    assert_nil token_translation.l1_end_character_index
  end

  test "should return nil for negative indices" do
    phrase = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: -1,  # Negative index
      l1_end_index: -1,
      translation: "test"
    )
    
    assert_nil token_translation.l1_start_character_index
    assert_nil token_translation.l1_end_character_index
  end

  test "should return nil when phrase text is blank" do
    phrase = Phrase.create!(
      text_l1: "",
      text_l2: "Hola mundo",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "test"
    )
    
    assert_nil token_translation.l1_start_character_index
    assert_nil token_translation.l1_end_character_index
  end

  test "should return nil when indices are nil" do
    phrase = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: nil,
      l1_end_index: nil,
      translation: "test"
    )
    
    assert_nil token_translation.l1_start_character_index
    assert_nil token_translation.l1_end_character_index
  end

  test "should handle complex punctuation and special characters" do
    phrase = Phrase.create!(
      text_l1: "Hello, world! How are you?",  # Words: ["Hello", "world", "How", "are", "you"]
      text_l2: "¡Hola mundo! ¿Cómo estás?",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 1,  # "world"
      l1_end_index: 1,
      translation: "mundo"
    )
    
    # "world" starts at character index 7 (after "Hello, ")
    assert_equal 7, token_translation.l1_start_character_index
    assert_equal 12, token_translation.l1_end_character_index
  end

  test "should handle unicode characters" do
    phrase = Phrase.create!(
      text_l1: "Café résumé naïve",  # Words: ["Café", "résumé", "naïve"]
      text_l2: "Coffee resumen ingenuo",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 1,  # "résumé"
      l1_end_index: 1,
      translation: "resumen"
    )
    
    # "résumé" starts at character index 5 (after "Café ")
    assert_equal 5, token_translation.l1_start_character_index
    assert_equal 11, token_translation.l1_end_character_index
  end

  test "should handle l2 indices with repeated words" do
    phrase = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo hola",  # Words: ["Hola", "mundo", "hola"] - "hola" appears twice
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 2,  # Second "hola"
      l2_end_index: 2,
      translation: "Hello"
    )
    
    assert_equal 11, token_translation.l2_start_character_index
    assert_equal 15, token_translation.l2_end_character_index
  end

  test "comprehensive edge case - mixed scenario" do
    phrase = Phrase.create!(
      text_l1: "The cat's toy was the best",  # Words: ["The", "cat's", "toy", "was", "the", "best"]
      text_l2: "El juguete del gato era el mejor",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    # Test first "the"
    token1 = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 0,  # First "The"
      l1_end_index: 0,
      translation: "El"
    )
    
    assert_equal 0, token1.l1_start_character_index
    assert_equal 3, token1.l1_end_character_index
    
    # Test second "the" 
    token2 = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 4,  # Second "the"
      l1_end_index: 4,
      translation: "el"
    )
    
    # Second "the" starts at character index 18 (after "The cat's toy was ")
    assert_equal 18, token2.l1_start_character_index
    assert_equal 21, token2.l1_end_character_index
    
    # Test multi-word token
    token3 = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 1,  # "cat's toy"
      l1_end_index: 2,
      translation: "juguete del gato"
    )
    
    assert_equal 4, token3.l1_start_character_index
    assert_equal 13, token3.l1_end_character_index
  end

  test "integration test - character indices should match original_text extraction" do
    phrase = Phrase.create!(
      text_l1: "The quick brown fox jumps",
      text_l2: "El zorro marrón rápido salta",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 1,  # "quick brown"
      l1_end_index: 2,
      translation: "rápido marrón"
    )
    
    # Get character indices
    start_char = token_translation.l1_start_character_index
    end_char = token_translation.l1_end_character_index
    
    # Extract text using character indices
    extracted_text = phrase.text_l1[start_char...end_char]
    
    # Should match the original_text method
    assert_equal token_translation.original_text, extracted_text
    assert_equal "quick brown", extracted_text
  end
end
