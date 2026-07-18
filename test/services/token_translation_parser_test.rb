require 'test_helper'

class TokenTranslationParserTest < ActiveSupport::TestCase
  setup do
    @phrase1 = build_translated_phrase(text_l1: "Pensé que era un buen momento", text_l2: "I thought it was a good time", id: 1)
    @phrase2 = build_translated_phrase(text_l1: "Por fin se hacía realidad", text_l2: "It was finally coming true", id: 2)
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
    parsed_phrases = parser.call
    translations = parsed_phrases.flat_map(&:translated_phrase_tokens)

    assert_same @phrases, parsed_phrases
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
    parser.call

    assert_equal 4, @phrase1.translated_phrase_tokens.length
    assert_equal 2, @phrase2.translated_phrase_tokens.length
  end

  test 'handles mismatched number of blocks' do
    extra_block_response = @llm_response + "\n\nExtra block"
    parser = TokenTranslationParser.new([@phrase1], extra_block_response)
    parser.call

    assert_equal 4, @phrase1.translated_phrase_tokens.length # Only first block matched
  end

  test 'does not add tokens for a mismatched block' do
    mismatched_response = "[Mismatched] text => something"
    parser = TokenTranslationParser.new([@phrase1], mismatched_response)
    parser.call

    assert_empty @phrase1.phrase_tokens
  end
end
