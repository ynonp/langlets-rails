require "test_helper"

class TokenTranslationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    # Create scripts
    @latin_script = Script.create!(
      name: 'latin',
      iso_code: 'Latn',
      rtl: false
    )
    
    # Create test languages
    @l1_language = Language.create!(
      iso_name: 'en',
      english_name: 'English',
      native_name: 'English',
      default_script: @latin_script
    )
    
    @l2_language = Language.create!(
      iso_name: 'es', 
      english_name: 'Spanish',
      native_name: 'Español',
      default_script: @latin_script
    )
    
    # Create test medium
    @medium = Medium.create!(
      url: 'https://example.com'
    )

    # Create test phrase
    @phrase = create_phrase_with_text(
      text_l1: "Hello world",
      text_l2: "Hola mundo", 
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
  end

  test "should create token translation with valid attributes" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 0,
      l2_end_index: 0,
      translation: "Hola"
    )
    
    assert token_translation.persisted?
    assert_equal @phrase, token_translation.phrase
    assert_equal "Hola", token_translation.translation
  end

  test "original_text should return correct text based on word indices" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    
    assert_equal "Hello", token_translation.original_text
    
    # Test with second word
    token_translation.update!(l1_start_index: 1, l1_end_index: 1)
    assert_equal "world", token_translation.original_text
  end

  test "original_text should handle multi-word tokens" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 1,  # Both words
      translation: "Hola mundo"
    )
    
    assert_equal "Hello world", token_translation.original_text
  end

  test "original_text should return empty string for invalid indices" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: nil,
      l1_end_index: nil,
      translation: "test"
    )
    
    assert_equal "", token_translation.original_text
  end

  test "original_text should return empty string for out of bounds indices" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 10,  # Out of bounds
      l1_end_index: 10,
      translation: "test"
    )
    
    assert_equal "", token_translation.original_text
  end

  test "should queue audio generation job on create" do
    assert_enqueued_jobs 1, only: GenerateTokenAudioJob do
      TokenTranslation.create!(
        phrase: @phrase,
        l1_start_index: 0,
        l1_end_index: 0,
        translation: "Hola"
      )
    end
  end

  test "should queue audio generation job on index update" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    
    assert_enqueued_jobs 1, only: GenerateTokenAudioJob do
      token_translation.update!(l1_end_index: 1)  # Change to valid range
    end
  end

  test "should not queue audio generation job when non-index attributes change" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    
    assert_no_enqueued_jobs do
      token_translation.update!(translation: "Hello")
    end
  end

  test "with_questions scope should work correctly" do
    # Create token without questions
    token_without_questions = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    
    # Create token with questions
    token_with_questions = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 1,
      l1_end_index: 1,
      translation: "mundo",
      questions: ["What does this mean?"]
    )
    
    tokens_with_questions = TokenTranslation.with_questions
    
    assert_includes tokens_with_questions, token_with_questions
    assert_not_includes tokens_with_questions, token_without_questions
  end

  test "should handle contractions correctly" do
    phrase = create_phrase_with_text(
      text_l1: "I don't like it",
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
    
    assert_equal "don't", token_translation.original_text
  end

  test "should handle unicode characters correctly" do
    phrase = create_phrase_with_text(
      text_l1: "Café résumé naïve",
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
    
    assert_equal "résumé", token_translation.original_text
  end
end
