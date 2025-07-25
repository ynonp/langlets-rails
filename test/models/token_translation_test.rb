require "test_helper"

class TokenTranslationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    # Create test phrase using factory with language fixtures
    @phrase = create(:phrase, 
      medium: medium(:a_dios_le_pido),
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      l1: languages(:english),
      l2: languages(:spanish)
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
    hello = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    
    assert_equal "Hello", hello.original_text
    
    # Test with second word
    world = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 1,
      l1_end_index: 1,
      translation: "mundo"
    )
    assert_equal "world", world.original_text
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

  test "invalid indices are validation error" do
    token_translation = TokenTranslation.new(
      phrase: @phrase,
      l1_start_index: nil,
      l1_end_index: nil,
      translation: "test"
    )
    
    refute token_translation.valid?
  end

  test "should not allow out of bounds indices" do
    token_translation = TokenTranslation.new(
      phrase: @phrase,
      l1_start_index: 10,  # Out of bounds
      l1_end_index: 10,
      translation: "test"
    )
    
    assert_not token_translation.valid?
    assert_includes token_translation.errors[:l1_start_index], "word indexes out of bounds"
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

  test "should handle unicode characters correctly" do
    phrase = create(:phrase,
      medium: medium(:a_dios_le_pido),
      text_l1: "Café résumé naïve",
      text_l2: "Coffee resumen ingenuo",
      l1: languages(:english),
      l2: languages(:spanish)
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
