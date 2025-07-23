require "test_helper"

class WordBasedTokenTranslationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    # Create test languages
    @spanish = Language.create!(
      iso_name: 'es',
      english_name: 'Spanish',
      native_name: 'Español'
    )
    
    @english = Language.create!(
      iso_name: 'en', 
      english_name: 'English',
      native_name: 'English'
    )
    
    # Create test medium
    @medium = Medium.create!(
      url: 'https://youtube.com/watch?v=test'
    )
  end

  test "should create TokenTranslation with word indexes matching juanes.json format" do
    # Test phrase from juanes.json
    phrase = Phrase.create!(
      text_l1: "Que mis ojos se despierten con la luz de tu mirada, yo",
      text_l2: "That my eyes may be awaken with the light of your gaze, I", 
      l1: @spanish,
      l2: @english,
      medium: @medium,
      timestamp: "00:21"
    )

    # Test creating tokens like in juanes.json data
    # "Que" -> "That" (word index 0 -> 0)
    token1 = phrase.add_token_translation("Que", 0, "That", 0)
    assert_not_nil token1
    assert_equal 0, token1.l1_start_index
    assert_equal 0, token1.l1_end_index
    assert_equal 0, token1.l2_start_index
    assert_equal 0, token1.l2_end_index
    assert_equal "Que", token1.original_text
    assert_equal "That", token1.translation_text

    # "mis" -> "my" (word index 1 -> 1) 
    token2 = phrase.add_token_translation("mis", 0, "my", 0)
    assert_not_nil token2
    assert_equal 1, token2.l1_start_index
    assert_equal 1, token2.l1_end_index
    assert_equal 1, token2.l2_start_index
    assert_equal 1, token2.l2_end_index
    assert_equal "mis", token2.original_text
    assert_equal "my", token2.translation_text

    # "ojos" -> "eyes" (word index 2 -> 2)
    token3 = phrase.add_token_translation("ojos", 0, "eyes", 0)
    assert_not_nil token3
    assert_equal 2, token3.l1_start_index
    assert_equal 2, token3.l1_end_index
    assert_equal 2, token3.l2_start_index
    assert_equal 2, token3.l2_end_index
    assert_equal "ojos", token3.original_text
    assert_equal "eyes", token3.translation_text
  end

  test "should handle multi-word tokens correctly" do
    phrase = Phrase.create!(
      text_l1: "la luz de tu mirada",   # ["la", "luz", "de", "tu", "mirada"]
      text_l2: "the light of your gaze", # ["the", "light", "of", "your", "gaze"]
      l1: @spanish,
      l2: @english,
      medium: @medium,
      timestamp: "00:30"
    )

    # Multi-word: "tu mirada" -> "your gaze" (words 3-4 -> 3-4)
    token = phrase.add_token_translation("tu mirada", 0, "your gaze", 0)
    assert_not_nil token
    assert_equal 3, token.l1_start_index
    assert_equal 4, token.l1_end_index
    assert_equal 3, token.l2_start_index
    assert_equal 4, token.l2_end_index
    assert_equal "tu mirada", token.original_text
    assert_equal "your gaze", token.translation_text
  end

  test "should handle tokens without L2 alignment" do
    phrase = Phrase.create!(
      text_l1: "Hola mundo hermoso",
      text_l2: "Hello beautiful world", 
      l1: @spanish,
      l2: @english,
      medium: @medium,
      timestamp: "00:05"
    )

    # Token with no L2 alignment (translation_occurrence = -1)
    token = phrase.add_token_translation("Hola", 0, "Hello", -1)
    assert_not_nil token
    assert_equal 0, token.l1_start_index
    assert_equal 0, token.l1_end_index
    assert_nil token.l2_start_index
    assert_nil token.l2_end_index
    assert_equal "Hola", token.original_text
    assert_equal "Hello", token.translation_text  # Falls back to translation field
  end

  test "should validate word indexes are within bounds" do
    phrase = Phrase.create!(
      text_l1: "Corta frase",  # Only 2 words
      text_l2: "Short phrase",
      l1: @spanish,
      l2: @english,
      medium: @medium,
      timestamp: "00:10"
    )

    # Valid token
    token = TokenTranslation.new(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 1,
      translation: "Short phrase"
    )
    assert token.valid?

    # Invalid token - word index out of bounds
    invalid_token = TokenTranslation.new(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 5,  # Out of bounds
      translation: "Invalid"
    )
    assert_not invalid_token.valid?
    assert_includes invalid_token.errors[:l1_start_index], "word indexes out of bounds"
  end

  test "tokenization should match expected word splitting" do
    phrase = Phrase.create!(
      text_l1: "Don't worry, it's working!",  # Should handle contractions
      text_l2: "No te preocupes, está funcionando!",
      l1: @english,
      l2: @spanish,
      medium: @medium,
      timestamp: "00:15"
    )

    # Test our tokenization logic
    l1_words = phrase.send(:tokenize, phrase.text_l1)
    expected_words = ["Don't", "worry", "it's", "working"]
    assert_equal expected_words, l1_words

    # Create token using the contraction
    token = phrase.add_token_translation("Don't", 0, "No", 0)
    assert_not_nil token
    assert_equal "Don't", token.original_text
  end

  test "should find existing tokens by word indexes" do
    phrase = Phrase.create!(
      text_l1: "Buenos días amigo",
      text_l2: "Good morning friend",
      l1: @spanish,
      l2: @english,
      medium: @medium,
      timestamp: "00:08"
    )

    # Create a token
    original_token = phrase.add_token_translation("Buenos", 0, "Good", 0)

    # Find it using word-based lookup
    found_token = phrase.find_token_translation("Buenos", 0)
    assert_not_nil found_token
    assert_equal original_token.id, found_token.id
    assert_equal 0, found_token.l1_start_index
    assert_equal 0, found_token.l1_end_index
  end
end