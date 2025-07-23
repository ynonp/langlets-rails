require "test_helper"

class JuanesDataImportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    # Create languages
    @spanish = Language.find_or_create_by!(
      iso_name: 'es',
      english_name: 'Spanish',
      native_name: 'Español'
    )
    
    @english = Language.find_or_create_by!(
      iso_name: 'en', 
      english_name: 'English',
      native_name: 'English'
    )
    
    # Create medium
    @medium = Medium.create!(
      url: 'https://youtube.com/watch?v=juanes_test'
    )
  end

  test "should import sample juanes.json data with word-based indexes" do
    # Sample data structure from juanes.json
    sample_data = {
      "text_l1" => "Que mis ojos se despierten con la luz de tu mirada, yo",
      "text_l2" => "That my eyes may be awaken with the light of your gaze, I",
      "timestamp" => "00:21",
      "translations" => [
        {
          "translation" => "That",
          "l1_index" => [0],    # word index in l1
          "l2_index" => [0],    # word index in l2
          "similar_sound" => nil,
          "listening_activity" => 0,
          "language_alignment_activity" => 0
        },
        {
          "translation" => "my",
          "l1_index" => [1],
          "l2_index" => [1],
          "similar_sound" => nil,
          "listening_activity" => 0,
          "language_alignment_activity" => 0
        },
        {
          "translation" => "eyes",
          "l1_index" => [2],
          "l2_index" => [2],
          "similar_sound" => ["hoyos", "rojos"],
          "listening_activity" => 1,
          "language_alignment_activity" => 1
        }
      ]
    }

    # Create phrase
    phrase = Phrase.create!(
      text_l1: sample_data["text_l1"],
      text_l2: sample_data["text_l2"],
      l1: @spanish,
      l2: @english,
      medium: @medium,
      timestamp: sample_data["timestamp"]
    )

    # Import token translations
    sample_data["translations"].each do |translation_data|
      l1_start_index = translation_data["l1_index"].first
      l1_end_index = translation_data["l1_index"].last
      l2_start_index = translation_data["l2_index"]&.first
      l2_end_index = translation_data["l2_index"]&.last

      token = TokenTranslation.create!(
        phrase: phrase,
        l1_start_index: l1_start_index,
        l1_end_index: l1_end_index,
        l2_start_index: l2_start_index,
        l2_end_index: l2_end_index,
        translation: translation_data["translation"],
        similar_sound: translation_data["similar_sound"]
      )

      # Verify word-based extraction works
      case translation_data["translation"]
      when "That"
        assert_equal "Que", token.original_text
        assert_equal "That", token.translation_text
      when "my" 
        assert_equal "mis", token.original_text
        assert_equal "my", token.translation_text
      when "eyes"
        assert_equal "ojos", token.original_text  
        assert_equal "eyes", token.translation_text
        assert_equal ["hoyos", "rojos"], token.similar_sound
      end
    end

    # Verify all tokens were created
    assert_equal 3, phrase.token_translations.count
    
    # Test that we can find tokens by their original text
    que_token = phrase.find_token_translation("Que", 0)
    assert_not_nil que_token
    assert_equal "That", que_token.translation
    
    mis_token = phrase.find_token_translation("mis", 0)
    assert_not_nil mis_token
    assert_equal "my", mis_token.translation
    
    ojos_token = phrase.find_token_translation("ojos", 0)
    assert_not_nil ojos_token
    assert_equal "eyes", ojos_token.translation
    assert_equal ["hoyos", "rojos"], ojos_token.similar_sound
  end

  test "should handle multi-word tokens from juanes.json format" do
    # Example with multi-word tokens
    sample_data = {
      "text_l1" => "la luz de tu mirada",
      "text_l2" => "the light of your gaze", 
      "timestamp" => "00:30",
      "translations" => [
        {
          "translation" => "the light",
          "l1_index" => [0, 1],    # multi-word: words 0-1
          "l2_index" => [0, 1],    # multi-word: words 0-1
        },
        {
          "translation" => "your gaze",
          "l1_index" => [3, 4],    # multi-word: words 3-4
          "l2_index" => [3, 4],    # multi-word: words 3-4
        }
      ]
    }

    phrase = Phrase.create!(
      text_l1: sample_data["text_l1"],
      text_l2: sample_data["text_l2"],
      l1: @spanish,
      l2: @english,
      medium: @medium,
      timestamp: sample_data["timestamp"]
    )

    sample_data["translations"].each do |translation_data|
      l1_start_index = translation_data["l1_index"].first
      l1_end_index = translation_data["l1_index"].last
      l2_start_index = translation_data["l2_index"]&.first
      l2_end_index = translation_data["l2_index"]&.last

      token = TokenTranslation.create!(
        phrase: phrase,
        l1_start_index: l1_start_index,
        l1_end_index: l1_end_index,
        l2_start_index: l2_start_index,
        l2_end_index: l2_end_index,
        translation: translation_data["translation"]
      )

      # Verify multi-word extraction
      case translation_data["translation"]
      when "the light"
        assert_equal "la luz", token.original_text
        assert_equal "the light", token.translation_text
      when "your gaze"
        assert_equal "tu mirada", token.original_text
        assert_equal "your gaze", token.translation_text
      end
    end

    assert_equal 2, phrase.token_translations.count
  end

  test "should validate juanes data format compatibility" do
    # Test that our word indexes match the juanes.json structure exactly
    phrase = Phrase.create!(
      text_l1: "Que mis ojos se despierten",  # ["Que", "mis", "ojos", "se", "despierten"]
      text_l2: "That my eyes may be awaken",  # ["That", "my", "eyes", "may", "be", "awaken"]
      l1: @spanish,
      l2: @english,
      medium: @medium,
      timestamp: "00:21"
    )

    # Verify our tokenization matches expected words
    l1_words = phrase.send(:tokenize, phrase.text_l1)
    l2_words = phrase.send(:tokenize, phrase.text_l2) 
    
    assert_equal ["Que", "mis", "ojos", "se", "despierten"], l1_words
    assert_equal ["That", "my", "eyes", "may", "be", "awaken"], l2_words

    # Test specific word indexes from juanes.json format
    token = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 2,  # "ojos" is at index 2
      l1_end_index: 2,
      l2_start_index: 2,  # "eyes" is at index 2
      l2_end_index: 2,
      translation: "eyes"
    )

    assert_equal "ojos", token.original_text
    assert_equal "eyes", token.translation_text
    
    # Test the indexes are exactly what juanes.json expects
    assert_equal 2, token.l1_start_index
    assert_equal 2, token.l1_end_index
    assert_equal 2, token.l2_start_index
    assert_equal 2, token.l2_end_index
  end
end