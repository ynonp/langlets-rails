require 'test_helper'

class SimilarSoundParserTest < ActiveSupport::TestCase
  setup do
  end

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
    SimilarSoundParser.new(phrases, llm_response)
  end

  test "20 de enero" do
    llm_response <<~END
    Pensé que era un buen [recuerdo]
    Por fin se [vacía] realidad
    Tanto oír [marchar] de tu silencio
    Dicen que te [abraza] como el [bar]
    END
  end

  test "flowers" do
    llm_response <<~END
Output:
    We were good, we were [bold]
    Kinda dream that can't be [hold]
    We were [fight], 'till we weren't
    Built a [bomb] and watched it burn
    END
  end
end

