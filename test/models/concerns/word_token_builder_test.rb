require "test_helper"

class WordTokenBuilderTest < ActiveSupport::TestCase
  setup do
    @phrase = Phrase.new(text_l1: "Apateu, apateu", text_l2: "Apartment, apartment")
    @words = [
      { "text" => "Apateu,", "translation" => "Apartment,", "timestamp" => "00:06.50", "timestamp_end" => "00:07.10" },
      { "text" => "apateu", "translation" => "apartment", "timestamp" => "00:07.25", "timestamp_end" => "00:07.80" },
    ]
  end

  test "builds one character-indexed token per word with timestamps" do
    @phrase.build_word_tokens(@words)
    tokens = @phrase.token_translations.sort_by(&:l1_start_index)

    assert_equal 2, tokens.length

    first = tokens[0]
    assert first.character_index?
    assert_equal 0, first.l1_start_index
    assert_equal 6, first.l1_end_index # "Apateu," is 7 chars (0..6)
    assert_equal "Apartment,", first.translation
    assert_equal "00:06.50", first.start_timestamp
    assert_equal "00:07.10", first.end_timestamp
    assert_nil first.read_attribute(:l2_start_index)
    assert first.karaoke?

    second = tokens[1]
    assert_equal "apateu", @phrase.text_l1[second.l1_start_index..second.l1_end_index]
    assert_equal "apartment", second.translation
  end

  test "maps repeated words to distinct occurrences" do
    @phrase.build_word_tokens(@words)
    starts = @phrase.token_translations.map(&:l1_start_index).sort
    assert_equal [0, 8], starts # second "apateu" starts at index 8, not 0
  end

  test "skips words with blank translation" do
    words = [
      { "text" => "Apateu,", "translation" => "", "timestamp" => "00:06.50", "timestamp_end" => "00:07.10" },
      { "text" => "apateu", "translation" => "apartment", "timestamp" => "00:07.25", "timestamp_end" => "00:07.80" },
    ]
    @phrase.build_word_tokens(words)
    assert_equal 1, @phrase.token_translations.length
    assert_equal "apartment", @phrase.token_translations.first.translation
  end

  test "returns self and builds nothing for blank words" do
    assert_equal @phrase, @phrase.build_word_tokens([])
    assert_empty @phrase.token_translations
  end
end
