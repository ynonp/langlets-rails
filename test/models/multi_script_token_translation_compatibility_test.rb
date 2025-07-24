require "test_helper"

class MultiScriptTokenTranslationCompatibilityTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    # Create test languages
    @hebrew_language = Language.create!(
      iso_name: 'he',
      english_name: 'Hebrew',
      native_name: 'עברית',
      rtl: true
    )
    
    @english_language = Language.create!(
      iso_name: 'en', 
      english_name: 'English',
      native_name: 'English'
    )
    
    # Create test medium
    @medium = Medium.create!(
      url: 'https://example.com'
    )

    # Create scripts
    @hebrew_script = Script.create!(name: "hebrew", iso_code: "Hebr", rtl: true)
    @latin_script = Script.create!(name: "latin", iso_code: "Latn", rtl: false)
  end

  test "TokenTranslation should work with legacy text_l1 field" do
    # Create phrase with original text_l1 field
    phrase = Phrase.create!(
      text_l1: "שלום עולם",
      text_l2: "Hello world", 
      l1: @hebrew_language,
      l2: @english_language,
      medium: @medium,
      timestamp: "00:01:30"
    )

    # Create token translation using word-based indices
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 0,  # "שלום"
      l1_end_index: 0,
      l2_start_index: 0,  # "Hello"
      l2_end_index: 0,
      translation: "Hello"
    )

    # Verify TokenTranslation works correctly
    assert_equal "שלום", token_translation.original_text
    assert token_translation.persisted?
  end

  test "TokenTranslation should work with multi-script phrase texts" do
    # Create phrase with both legacy fields and new multi-script system
    phrase = Phrase.create!(
      text_l1: "שלום עולם",
      text_l2: "Hello world", 
      l1: @hebrew_language,
      l2: @english_language,
      medium: @medium,
      timestamp: "00:01:30"
    )

    # Add multi-script variants (this doesn't interfere with TokenTranslation)
    hebrew_text = PhraseText.create!(content: "שלום עולם", script: @hebrew_script)
    latin_text = PhraseText.create!(content: "Shalom olam", script: @latin_script)
    english_text = PhraseText.create!(content: "Hello world", script: @latin_script)
    
    PhraseTextAssignment.create!(phrase: phrase, phrase_text: hebrew_text, language_role: :l1, primary: true)
    PhraseTextAssignment.create!(phrase: phrase, phrase_text: latin_text, language_role: :l1, primary: false)
    PhraseTextAssignment.create!(phrase: phrase, phrase_text: english_text, language_role: :l2, primary: true)

    # TokenTranslation still uses the original text_l1 field
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 1,  # "עולם"
      l1_end_index: 1,
      l2_start_index: 1,  # "world"
      l2_end_index: 1,
      translation: "world"
    )

    # Verify TokenTranslation works correctly with original text
    assert_equal "עולם", token_translation.original_text
    
    # Verify multi-script variants are available
    assert_equal "שלום עולם", phrase.text_l1_for_script(script: "hebrew")
    assert_equal "Shalom olam", phrase.text_l1_for_script(script: "latin")
    assert_equal "Hello world", phrase.text_l2_for_script(script: "latin")
    
    # Verify both systems coexist
    assert_equal "שלום עולם", phrase.text_l1 # Original field
    assert_equal 2, phrase.text_l1_variants.count # New variants
  end

  test "word-based indexing should work correctly across different scripts" do
    # Create phrase with mixed script content
    phrase = Phrase.create!(
      text_l1: "Hello שלום world",  # Mixed Hebrew-English
      text_l2: "Hello peace world", 
      l1: @hebrew_language,
      l2: @english_language,
      medium: @medium,
      timestamp: "00:01:30"
    )

    # Test tokenization of mixed script text
    words = phrase.text_l1.tokenize
    expected_words = ["Hello", "שלום", "world"]
    assert_equal expected_words, words

    # Create token translation for Hebrew word in mixed text
    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 1,  # "שלום"
      l1_end_index: 1,
      l2_start_index: 1,  # "peace"
      l2_end_index: 1,
      translation: "peace"
    )

    assert_equal "שלום", token_translation.original_text
  end

  test "character index methods should work with new script variants" do
    phrase = Phrase.create!(
      text_l1: "שלום עולם",
      text_l2: "Hello world", 
      l1: @hebrew_language,
      l2: @english_language,
      medium: @medium,
      timestamp: "00:01:30"
    )

    token_translation = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 0,
      l2_end_index: 0,
      translation: "Hello"
    )

    # Verify character index methods still work
    assert_not_nil token_translation.l1_start_character_index
    assert_not_nil token_translation.l1_end_character_index
    assert_not_nil token_translation.l2_start_character_index
    assert_not_nil token_translation.l2_end_character_index
  end

  test "audio generation should still work with TokenTranslation" do
    phrase = Phrase.create!(
      text_l1: "שלום עולם",
      text_l2: "Hello world", 
      l1: @hebrew_language,
      l2: @english_language,
      medium: @medium,
      timestamp: "00:01:30"
    )

    # TokenTranslation should queue audio generation job
    assert_enqueued_jobs 1, only: GenerateTokenAudioJob do
      TokenTranslation.create!(
        phrase: phrase,
        l1_start_index: 0,
        l1_end_index: 0,
        translation: "Hello"
      )
    end
  end
end