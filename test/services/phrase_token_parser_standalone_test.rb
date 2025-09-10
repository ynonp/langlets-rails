require 'minitest/autorun'

# Load the parser class without Rails dependencies
require_relative '../../app/services/phrase_token_parser'

class PhraseTokenParserTest < Minitest::Test
  def setup
    @sample_input = <<~INPUT
      [We were] good, we were gold => [היינו] טובים, היינו זהב
      We were [good], we were gold => היינו [טובים], היינו זהב
      We were good, [we were] gold => היינו טובים, [היינו] זהב
      We were good, we were [gold] => היינו טובים, היינו [זהב]

      [Kinda] dream that can't be sold => [סוג של] חלום שאי אפשר למכור
      Kinda [dream] that can't be sold => סוג של [חלום] שאי אפשר למכור
      Kinda dream [that] can't be sold => ש... # there is a ש in the example but we should only bracket full words
      Kinda dream that [can't] be sold => אי פאשר # there is no direct translation of "can't" in the translation text so I used a new word
      Kinda dream that can't [be] sold => להיות
      Kinda dream that can't be [sold] => להימכר

      [We were] right 'til we weren't => [היינו] צודקים, עד שכבר לא
      We were [right] 'til we weren't => היינו [צודקים], עד שכבר לא
      We were right ['til] we weren't => היינו צודקים, [עד שכבר] לא # 'til is actually just "until" which is "עד ש", but we only bracket full words so added שכבר
      We were right 'til [we weren't] => לא היינו # we weren't literally means לא היינו, even though here it is used for עד שכבר לא היינו

      [Built] a home and watched it burn => [בנינו] בית וראינו אותו נשרף
      Built [a home] and watched it burn => בנינו [בית] וראינו אותו נשרף
      Built a home [and] watched it burn => ו # use custom translation because ו in the Hebrew text is connected to the next word
      Built a home and [watched] it burn => בנינו בית [וראינו] אותו נשרף # even though watched is ראינו we should only select full words.
      Built a home and watched [it] burn => בנינו בית וראינו [אותו] נשרף
      Built a home and watched it [burn] => בנינו בית וראינו אותו [נשרף]
    INPUT

    @parser = PhraseTokenParser.new(@sample_input)
  end

  def test_parses_correct_number_of_phrases
    phrases = @parser.parse
    assert_equal 4, phrases.length
  end

  def test_parses_first_phrase_correctly
    phrases = @parser.parse
    first_phrase = phrases[0]
    
    assert_equal "We were good, we were gold", first_phrase.l1_text
    assert_equal "היינו טובים, היינו זהב", first_phrase.l2_text
    assert_equal 4, first_phrase.token_translations.length
  end

  def test_parses_first_phrase_first_token_translation
    phrases = @parser.parse
    first_phrase = phrases[0]
    first_token = first_phrase.token_translations[0]
    
    assert_equal 0, first_token.l1_start_index
    assert_equal 1, first_token.l1_end_index
    assert_equal 0, first_token.l2_start_index
    assert_equal 0, first_token.l2_end_index
    assert_equal "היינו", first_token.translation
  end

  def test_parses_first_phrase_second_token_translation
    phrases = @parser.parse
    first_phrase = phrases[0]
    second_token = first_phrase.token_translations[1]
    
    assert_equal 2, second_token.l1_start_index
    assert_equal 2, second_token.l1_end_index
    assert_equal 1, second_token.l2_start_index
    assert_equal 1, second_token.l2_end_index
    assert_equal "טובים", second_token.translation
  end

  def test_parses_token_translation_without_l2_mapping
    phrases = @parser.parse
    second_phrase = phrases[1]
    
    # Find the "that" token translation (should be third one: Kinda dream [that] can't be sold => ש...)
    that_token = second_phrase.token_translations.find { |t| t.translation == "ש..." }
    
    refute_nil that_token
    assert_equal 2, that_token.l1_start_index
    assert_equal 2, that_token.l1_end_index
    assert_nil that_token.l2_start_index
    assert_nil that_token.l2_end_index
    assert_equal "ש...", that_token.translation
  end

  def test_parses_custom_translation_without_direct_mapping
    phrases = @parser.parse
    second_phrase = phrases[1]
    
    # Find the "can't" token translation
    cant_token = second_phrase.token_translations.find { |t| t.translation == "אי פאשר" }
    
    refute_nil cant_token
    assert_equal 3, cant_token.l1_start_index
    assert_equal 3, cant_token.l1_end_index
    assert_nil cant_token.l2_start_index
    assert_nil cant_token.l2_end_index
    assert_equal "אי פאשר", cant_token.translation
  end

  def test_parses_multi_word_brackets
    phrases = @parser.parse
    first_phrase = phrases[0]
    
    # Test "we were" token (third token should be the second occurrence)
    we_were_token = first_phrase.token_translations.find { |t| t.l1_start_index == 3 && t.l1_end_index == 4 }
    
    refute_nil we_were_token
    assert_equal "היינו", we_were_token.translation
  end

  def test_parses_phrase_with_apostrophe_correctly
    phrases = @parser.parse
    third_phrase = phrases[2]
    
    assert_equal "We were right 'til we weren't", third_phrase.l1_text
    assert_equal "היינו צודקים, עד שכבר לא", third_phrase.l2_text
  end

  def test_ignores_comments_in_parsing
    phrases = @parser.parse
    
    # All translations should be parsed without comments
    phrases.each do |phrase|
      phrase.token_translations.each do |token|
        refute_includes token.translation, "#"
      end
    end
  end

  def test_parses_til_token_with_extended_translation
    phrases = @parser.parse
    third_phrase = phrases[2]
    
    til_token = third_phrase.token_translations.find { |t| t.translation == "עד שכבר" }
    
    refute_nil til_token
    assert_equal 3, til_token.l1_start_index
    assert_equal 3, til_token.l1_end_index
    assert_equal 2, til_token.l2_start_index
    assert_equal 3, til_token.l2_end_index
  end

  def test_parses_single_character_translation
    phrases = @parser.parse
    fourth_phrase = phrases[3]
    
    and_token = fourth_phrase.token_translations.find { |t| t.translation == "ו" }
    
    refute_nil and_token
    assert_equal 3, and_token.l1_start_index
    assert_equal 3, and_token.l1_end_index
    assert_nil and_token.l2_start_index
    assert_nil and_token.l2_end_index
    assert_equal "ו", and_token.translation
  end

  def test_parses_all_token_translations_for_fourth_phrase
    phrases = @parser.parse
    fourth_phrase = phrases[3]
    
    assert_equal "Built a home and watched it burn", fourth_phrase.l1_text
    assert_equal "בנינו בית וראינו אותו נשרף", fourth_phrase.l2_text
    assert_equal 6, fourth_phrase.token_translations.length
  end

  def test_token_translations_have_correct_word_mappings
    phrases = @parser.parse
    fourth_phrase = phrases[3]
    
    # Test "Built" -> "בנינו"
    built_token = fourth_phrase.token_translations.find { |t| t.l1_start_index == 0 && t.l1_end_index == 0 }
    refute_nil built_token
    assert_equal "בנינו", built_token.translation
    
    # Test "it" -> "אותו"
    it_token = fourth_phrase.token_translations.find { |t| t.translation == "אותו" }
    refute_nil it_token
    assert_equal 5, it_token.l1_start_index
    assert_equal 5, it_token.l1_end_index
  end
end