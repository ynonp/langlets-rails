require "test_helper"

class CopiedWordTranslationsTest < ActiveSupport::TestCase
  setup do
    Current.translation_language = languages(:hebrew)
    medium = Medium.create!(url: "https://www.youtube.com/watch?v=copied-gloss", language: languages(:english))
    @phrase = Phrase.create!(medium:, l1: languages(:english), text_l1: "I am afraid", timestamp: "00:10")
    @token = @phrase.phrase_tokens.create!(
      index_type: :character_index, l1_start_index: 2, l1_end_index: 3,
      start_timestamp: "00:10.20", end_timestamp: "00:10.40", part_of_speech: "auxiliary"
    )
    @translation = @token.token_translations.create!(language: languages(:hebrew), translation: "am")
  end

  teardown { Current.reset }

  test "copied AI glosses are unavailable without deleting the source token or raw output" do
    assert_nil @token.translation
    assert_nil @token.effective_translation
    assert_nil @token.l2_start_index
    assert @token.karaoke?
    assert_equal "am", @token.original_text
    assert_equal "00:10.40", @token.end_timestamp
    assert_equal "am", @translation.reload.translation
  end

  test "case, surrounding punctuation and whitespace do not disguise a copied gloss" do
    @translation.update!(translation: "  ‘AM!’  ")
    assert_nil @token.reload.translation
  end

  test "a copied preferred gloss does not fall back to a different language" do
    other = @token.token_translations.create!(language: languages(:spanish), translation: "soy")
    @token.resolved_translation = other
    assert_nil @token.translation
  end

  test "useful preferred and fallback translations remain available" do
    @translation.update!(translation: "אני")
    assert_equal "אני", @token.reload.translation

    Current.translation_language = languages(:spanish)
    assert_equal "אני", @token.reload.translation
  end

  test "internal punctuation remains significant" do
    @phrase.update!(text_l1: "it's")
    @token.update!(l1_start_index: 0, l1_end_index: 3)
    @translation.update!(translation: "its")
    assert_equal "its", @token.reload.translation
  end

  test "an identical cognate is also skipped" do
    @phrase.update!(text_l1: "hotel")
    @token.update!(l1_start_index: 0, l1_end_index: 4)
    @translation.update!(translation: "hotel")
    assert_nil @token.reload.translation
  end

  test "building AI word tokens retains copied words and their timing" do
    @phrase.build_word_tokens([
      { "text" => "I", "translation" => "אני [pronoun]", "timestamp" => "00:10.00", "timestamp_end" => "00:10.20" },
      { "text" => "am", "translation" => "am [auxiliary]", "timestamp" => "00:10.20", "timestamp_end" => "00:10.40" },
      { "text" => "afraid", "translation" => "פוחד [adjective]", "timestamp" => "00:10.40", "timestamp_end" => "00:11.00" }
    ])
    tokens = @phrase.phrase_tokens.reload.order(:l1_start_index).to_a
    assert_equal ["I", "am", "afraid"], tokens.map(&:original_text)
    assert_equal ["אני", nil, "פוחד"], tokens.map(&:translation)
    assert tokens.all?(&:karaoke?)
  end
end
