require 'test_helper'

class TokenTranslationParserTest < ActiveSupport::TestCase
  setup do
    @phrase1 = Phrase.new(text_l1: "Pensé que era un buen momento", text_l2: "I thought it was a good time", id: 1)
    @phrase2 = Phrase.new(text_l1: "Por fin se hacía realidad", text_l2: "It was finally coming true", id: 2)
    @phrases = [@phrase1, @phrase2]
    @llm_response = "[Pensé] que era un buen momento => [I thought] it was a good time
Pensé que [era] un buen momento => I thought [it was] a good time
Pensé que era un [buen] momento => I thought it was a [good] time
Pensé que era un buen [momento] => moment, time

[Por fin] se hacía realidad => It was [finally] coming true
Por fin [se hacía] realidad => was getting, was becoming # custom translation"
  end

  test 'parses multiple phrases from full LLM response' do
    parser = TokenTranslationParser.new(@phrases, @llm_response)
    translations = parser.call
    assert_equal 6, translations.length

    # First phrase translations
    first_phrase_trans = translations[0..3]
    assert_equal 1, first_phrase_trans[0][:phrase_id]

    # Second phrase translations
    second_phrase_trans = translations[4..5]
    assert_equal 2, second_phrase_trans[0][:phrase_id]
    assert_nil second_phrase_trans[1][:l2_start_index] # custom translation
    assert_equal 'was getting, was becoming', second_phrase_trans[1][:translation]
  end

  test 'matches blocks to phrases correctly' do
    parser = TokenTranslationParser.new(@phrases, @llm_response)
    translations = parser.call
    assert_operator translations.length, :>, 0
  end

  test 'handles mismatched number of blocks' do
    extra_block_response = @llm_response + "\n\nExtra block"
    parser = TokenTranslationParser.new([@phrase1], extra_block_response)
    translations = parser.call
    assert_equal 4, translations.length # Only first block matched
  end

  test 'returns empty if no matching blocks' do
    mismatched_response = "[Mismatched] text => something"
    parser = TokenTranslationParser.new([@phrase1], mismatched_response)
    assert_equal [], parser.call
  end
end

class TokenTranslationParser
  def initialize(phrases, llm_response)
    @phrases = phrases
    @llm_response = llm_response
    @blocks = split_into_blocks(llm_response)
  end

  def call
    all_translations = []

    @phrases.each_with_index do |phrase, idx|
      block = @blocks[idx]
      next unless block

      next unless matches_phrase?(block, phrase)

      translations = phrase.parse(block)
      all_translations.concat(translations)
    end

    all_translations
  end

  private

  def split_into_blocks(response)
    response.to_s.split(/\n\s*\n/).map(&:strip).reject(&:empty?)
  end

  def matches_phrase?(block, phrase)
    lines = block.split("\n")
    phrase_text = phrase.text_l1.strip
    lines.any? do |line|
      parts = line.split('=>', 2)
      next false unless parts.length == 2
      left_side = parts[0].strip
      left_clean = left_side.gsub(/\[.*?\]/, '').strip
      phrase_text.include?(left_clean)
    end
  end
end
