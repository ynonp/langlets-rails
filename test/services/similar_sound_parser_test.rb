require 'test_helper'

class SimilarSoundParserTest < ActiveSupport::TestCase
  test "redemption song" do
    llm_response = <<~END
Output:
    [Gold] pirates yes they rob I
    Sold I to the merchant ships
    Minutes after they [book] I
    From the [motherless] pit.
    END

    phrases = [
      Phrase.new(text_l1: "Old pirates yes they rob I"),
      Phrase.new(text_l1: "Sold I to the mechant ships"),
      Phrase.new(text_l1: "Minutes after they took I"),
      Phrase.new(text_l1: "From the bottomless pit")
    ]

    p = SimilarSoundParser.new(phrases, llm_response)
    p.call

    assert_equal phrases[0].similar_sounds.size, 1
    assert_equal phrases[0].similar_sounds.first.start_word_index, 0
    assert_equal phrases[0].similar_sounds.first.end_word_index, 0
    assert_equal phrases[0].similar_sounds.first.replacement_text, "Gold"

    assert_equal phrases[1].similar_sounds.size, 0

    assert_equal phrases[2].similar_sounds.size, 1
    assert_equal phrases[2].similar_sounds.first.start_word_index, 3
    assert_equal phrases[2].similar_sounds.first.end_word_index, 3
    assert_equal phrases[2].similar_sounds.first.replacement_text, "book"

    assert_equal phrases[3].similar_sounds.size, 1
    assert_equal phrases[3].similar_sounds.first.start_word_index, 2
    assert_equal phrases[3].similar_sounds.first.end_word_index, 2
    assert_equal phrases[3].similar_sounds.first.replacement_text, "motherless"
  end

  test "20 de enero" do
    llm_response = <<~END
    Pensé que era un buen [recuerdo]
    Por fin se [vacía] realidad
    Tanto oír [marchar] de tu silencio
    Dicen que te [abraza] como el [bar]
    END

    phrases = [
      Phrase.new(text_l1: "Pensé que era un buen momento"),
      Phrase.new(text_l1: "Por fin se hacia realidad"),
      Phrase.new(text_l1: "Tanto oír hablar de tu silencio"),
      Phrase.new(text_l1: "Dicen que te arrastra como el mar")
    ]

    p = SimilarSoundParser.new(phrases, llm_response)
    p.call

    assert_equal phrases[0].similar_sounds.size, 1
    assert_equal phrases[0].similar_sounds.first.start_word_index, 5
    assert_equal phrases[0].similar_sounds.first.end_word_index, 5
    assert_equal phrases[0].similar_sounds.first.replacement_text, "recuerdo"

    assert_equal phrases[1].similar_sounds.size, 1
    assert_equal phrases[1].similar_sounds.first.start_word_index, 3
    assert_equal phrases[1].similar_sounds.first.end_word_index, 3
    assert_equal phrases[1].similar_sounds.first.replacement_text, "vacía"

    assert_equal phrases[2].similar_sounds.size, 1
    assert_equal phrases[2].similar_sounds.first.start_word_index, 2
    assert_equal phrases[2].similar_sounds.first.end_word_index, 2
    assert_equal phrases[2].similar_sounds.first.replacement_text, "marchar"

    assert_equal phrases[3].similar_sounds.size, 2
    assert_equal phrases[3].similar_sounds.first.start_word_index, 3
    assert_equal phrases[3].similar_sounds.first.end_word_index, 3
    assert_equal phrases[3].similar_sounds.first.replacement_text, "abraza"

    assert_equal phrases[3].similar_sounds.second.start_word_index, 6
    assert_equal phrases[3].similar_sounds.second.end_word_index, 6
    assert_equal phrases[3].similar_sounds.second.replacement_text, "bar"
  end

  test "flowers" do
    llm_response  = <<~END
Output:
    We were good, we were [bold]
    Kinda dream that can't be [hold]
    We were [fight], 'till we weren't
    Built a [bomb] and watched it burn
    END

    phrases = [
      Phrase.new(text_l1: "We were good, we were gold"),
      Phrase.new(text_l1: "Kinda dream that can't be sold"),
      Phrase.new(text_l1: "We were right, 'till we weren't"),
      Phrase.new(text_l1: "Built a home and watched it burn")
    ]

    p = SimilarSoundParser.new(phrases, llm_response)
    p.call

    assert_equal phrases[0].similar_sounds.size, 1
    assert_equal phrases[0].similar_sounds.first.start_word_index, 5
    assert_equal phrases[0].similar_sounds.first.end_word_index, 5
    assert_equal phrases[0].similar_sounds.first.replacement_text, "bold"

    assert_equal phrases[1].similar_sounds.size, 1
    assert_equal phrases[1].similar_sounds.first.start_word_index, 5
    assert_equal phrases[1].similar_sounds.first.end_word_index, 5
    assert_equal phrases[1].similar_sounds.first.replacement_text, "hold"

    assert_equal phrases[2].similar_sounds.size, 1
    assert_equal phrases[2].similar_sounds.first.start_word_index, 2
    assert_equal phrases[2].similar_sounds.first.end_word_index, 2
    assert_equal phrases[2].similar_sounds.first.replacement_text, "fight"

    assert_equal phrases[3].similar_sounds.size, 1
    assert_equal phrases[3].similar_sounds.first.start_word_index, 2
    assert_equal phrases[3].similar_sounds.first.end_word_index, 2
    assert_equal phrases[3].similar_sounds.first.replacement_text, "bomb"
  end
end

