require "test_helper"

class TokenTranslationCharacterIndexTest < ActiveSupport::TestCase
  def setup
    # Use existing fixtures and factories like other tests
    @medium = medium(:a_dios_le_pido)
    @l1_language = languages(:english)
    @l2_language = languages(:spanish)
  end

  test "l1_characters_range should return correct character range for single word" do
    phrase = create(:phrase, 
      medium: @medium,
      text_l1: "Hello beautiful world",  # Words: ["Hello", "beautiful", "world"]
      text_l2: "Hola mundo hermoso",
      l1: @l1_language,
      l2: @l2_language
    )
    
    token_translation = create(:token_translation,
      phrase: phrase,
      l1_start_index: 1,  # "beautiful"
      l1_end_index: 1,
      translation: "hermoso"
    )
    
    # "beautiful" starts at character index 6 (after "Hello ")
    range = token_translation.l1_characters_range
    assert_equal 6, range.begin
  end

  test "l1_characters_range end should return correct character position for single word" do
    phrase = create(:phrase, 
      medium: @medium,
      text_l1: "Hello beautiful world",  # Words: ["Hello", "beautiful", "world"]
      text_l2: "Hola mundo hermoso",
      l1: @l1_language,
      l2: @l2_language
    )
    
    token_translation = create(:token_translation,
      phrase: phrase,
      l1_start_index: 1,  # "beautiful"
      l1_end_index: 1,
      translation: "hermoso"
    )
    
    range = token_translation.l1_characters_range
    assert_equal 15, range.end
  end

  test "l1_characters_range should work for multi-word tokens" do
    phrase = create(:phrase,
      medium: @medium,
      text_l1: "Hello beautiful world",
      text_l2: "Hola mundo hermoso",
      l1: @l1_language,
      l2: @l2_language
    )
    
    token_translation = create(:token_translation,
      phrase: phrase,
      l1_start_index: 0,  # "Hello beautiful" (words 0 and 1)
      l1_end_index: 1,
      translation: "Hola hermoso"
    )
    
    range = token_translation.l1_characters_range
    assert_equal 0, range.begin
    assert_equal 15, range.end
  end

  test "l2_character_range should work correctly" do
    phrase = create(:phrase,
      medium: @medium,
      text_l1: "Hello world",
      text_l2: "Hola mundo hermoso",  # Words: ["Hola", "mundo", "hermoso"]
      l1: @l1_language,
      l2: @l2_language
    )
    
    token_translation = create(:token_translation,
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 1,  # "mundo"
      l2_end_index: 1,
      translation: "world"
    )
    
    range = token_translation.l2_characters_range
    assert_equal 5, range.begin
    assert_equal 10, range.end
  end

  test "should handle word appearing multiple times - first occurrence" do
    phrase = create(:phrase,
      medium: @medium,
      text_l1: "The cat and the dog",  # Words: ["The", "cat", "and", "the", "dog"]
      text_l2: "El gato y el perro",
      l1: @l1_language,
      l2: @l2_language
    )
    
    token_translation = create(:token_translation,
      phrase: phrase,
      l1_start_index: 0,  # First "The"
      l1_end_index: 0,
      translation: "El"
    )
    
    range = token_translation.l1_characters_range
    assert_equal 0, range.begin
    assert_equal 3, range.end
  end

  test "should handle word appearing multiple times - second occurrence" do
    phrase = create(:phrase,
      medium: @medium,
      text_l1: "The cat and the dog",  # Words: ["The", "cat", "and", "the", "dog"]
      text_l2: "El gato y el perro",
      l1: @l1_language,
      l2: @l2_language
    )
    
    token_translation = create(:token_translation,
      phrase: phrase,
      l1_start_index: 3,  # Second "the" (lowercase)
      l1_end_index: 3,
      translation: "el"
    )
    
    range = token_translation.l1_characters_range
    assert_equal 12, range.begin
    assert_equal 15, range.end
  end

  test "should handle contractions" do
    phrase = create(:phrase,
      medium: @medium,
      text_l1: "I don't like it",  # Words: ["I", "don't", "like", "it"]
      text_l2: "No me gusta",
      l1: @l1_language,
      l2: @l2_language
    )
    
    token_translation = create(:token_translation,
      phrase: phrase,
      l1_start_index: 1,  # "don't"
      l1_end_index: 1,
      translation: "No"
    )
    
    range = token_translation.l1_characters_range
    assert_equal 2, range.begin
    assert_equal 7, range.end
  end

  test "should handle word that appears as part of another word" do
    phrase = create(:phrase,
      medium: @medium,
      text_l1: "I saw a cat in the catalog",  # Words: ["I", "saw", "a", "cat", "in", "the", "catalog"]
      text_l2: "Vi un gato en el catálogo",
      l1: @l1_language,
      l2: @l2_language
    )
    
    token_translation = create(:token_translation,
      phrase: phrase,
      l1_start_index: 3,  # "cat" (should not match "catalog")
      l1_end_index: 3,
      translation: "gato"
    )
    
    # "cat" (the standalone word) starts at character index 8 (after "I saw a ")
    range = token_translation.l1_characters_range
    assert_equal 8, range.begin
    assert_equal 11, range.end
  end

  test "should return nil for negative indices" do
    phrase = create(:phrase,
      medium: @medium,
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      l1: @l1_language,
      l2: @l2_language
    )
    
    # Build the token_translation without saving to avoid validation errors
    token_translation = build(:token_translation,
      phrase: phrase,
      l1_start_index: -1,  # Negative index
      l1_end_index: -1,
      translation: "test"
    )
    
    refute token_translation.valid?
  end

  test "should return nil when phrase text is blank" do
    phrase = create(:phrase,
      medium: @medium,
      text_l1: "",
      text_l2: "Hola mundo",
      l1: @l1_language,
      l2: @l2_language
    )
    
    # Build the token_translation without saving to avoid validation errors
    token_translation = build(:token_translation,
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "test"
    )
    
    refute token_translation.valid?
  end

  test "should handle complex punctuation and special characters" do
    phrase = create(:phrase,
      medium: @medium,
      text_l1: "Hello, world! How are you?",  # Words: ["Hello", "world", "How", "are", "you"]
      text_l2: "¡Hola mundo! ¿Cómo estás?",
      l1: @l1_language,
      l2: @l2_language
    )
    
    token_translation = create(:token_translation,
      phrase: phrase,
      l1_start_index: 1,  # "world"
      l1_end_index: 1,
      translation: "mundo"
    )
    
    # "world" starts at character index 7 (after "Hello, ")
    range = token_translation.l1_characters_range
    assert_equal 7, range.begin
    assert_equal 12, range.end
  end

  test "should handle unicode characters" do
    phrase = create(:phrase,
      medium: @medium,
      text_l1: "Café résumé naïve",  # Words: ["Café", "résumé", "naïve"]
      text_l2: "Coffee resumen ingenuo",
      l1: @l1_language,
      l2: @l2_language
    )
    
    token_translation = create(:token_translation,
      phrase: phrase,
      l1_start_index: 1,  # "résumé"
      l1_end_index: 1,
      translation: "resumen"
    )
    
    # "résumé" starts at character index 5 (after "Café ")
    range = token_translation.l1_characters_range
    assert_equal 5, range.begin
    assert_equal 11, range.end
  end

  test "should handle l2_character_range with repeated words" do
    phrase = create(:phrase,
      medium: @medium,
      text_l1: "Hello world",
      text_l2: "Hola mundo hola",  # Words: ["Hola", "mundo", "hola"] - "hola" appears twice
      l1: @l1_language,
      l2: @l2_language
    )
    
    token_translation = create(:token_translation,
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 2,  # Second "hola"
      l2_end_index: 2,
      translation: "Hello"
    )
    
    range = token_translation.l2_characters_range
    assert_equal 11, range.begin
    assert_equal 15, range.end
  end

  test "comprehensive edge case - mixed scenario" do
    phrase = create(:phrase,
      medium: @medium,
      text_l1: "The cat's toy was the best",  # Words: ["The", "cat's", "toy", "was", "the", "best"]
      text_l2: "El juguete del gato era el mejor",
      l1: @l1_language,
      l2: @l2_language
    )
    
    # Test first "the"
    token1 = create(:token_translation,
      phrase: phrase,
      l1_start_index: 0,  # First "The"
      l1_end_index: 0,
      translation: "El"
    )
    
    range1 = token1.l1_characters_range
    assert_equal 0, range1.begin
    assert_equal 3, range1.end
    
    # Test second "the" 
    token2 = create(:token_translation,
      phrase: phrase,
      l1_start_index: 4,  # Second "the"
      l1_end_index: 4,
      translation: "el"
    )
    
    # Second "the" starts at character index 18 (after "The cat's toy was ")
    range2 = token2.l1_characters_range
    assert_equal 18, range2.begin
    assert_equal 21, range2.end
    
    # Test multi-word token
    token3 = create(:token_translation,
      phrase: phrase,
      l1_start_index: 1,  # "cat's toy"
      l1_end_index: 2,
      translation: "juguete del gato"
    )
    
    range3 = token3.l1_characters_range
    assert_equal 4, range3.begin
    assert_equal 13, range3.end
  end

  test "integration test - character range should match original_text extraction" do
    phrase = create(:phrase,
      medium: @medium,
      text_l1: "The quick brown fox jumps",
      text_l2: "El zorro marrón rápido salta",
      l1: @l1_language,
      l2: @l2_language
    )
    
    token_translation = create(:token_translation,
      phrase: phrase,
      l1_start_index: 1,  # "quick brown"
      l1_end_index: 2,
      translation: "rápido marrón"
    )
    
    # Get character range
    range = token_translation.l1_characters_range
    
    # Extract text using character range
    extracted_text = phrase.text_l1.to_s[range]
    
    # Should match the original_text method
    assert_equal token_translation.original_text, extracted_text
    assert_equal "quick brown", extracted_text
  end
end
