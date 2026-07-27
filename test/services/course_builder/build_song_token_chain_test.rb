require "test_helper"

class CourseBuilder::BuildSongTokenChainTest < ActiveSupport::TestCase
  Token = Struct.new(:part_of_speech, :original_text, :translation)

  test "selects one content-word part of speech with unambiguous answers" do
    tokens = [
      Token.new("verb", "want", "querer"),
      Token.new("verb", "need", "necesitar"),
      Token.new("verb", "know", "saber"),
      Token.new("verb", "find", "encontrar"),
      Token.new("noun", "Paris", "París"),
      Token.new("proper_noun", "John", "Juan"),
      Token.new("pronoun", "I", "yo")
    ]

    selected = builder.send(:token_chain_tokens, tokens)

    assert_equal 4, selected.size
    assert_equal [ "verb" ], selected.map(&:part_of_speech).uniq
  end

  test "returns no tokens when no category has four unique pairs" do
    tokens = [
      Token.new("noun", "song", "canción"),
      Token.new("noun", "song", "melodía"),
      Token.new("noun", "voice", "voz"),
      Token.new("noun", "heart", "corazón"),
      Token.new("verb", "sing", "cantar"),
      Token.new("verb", "dance", "bailar")
    ]

    assert_empty builder.send(:token_chain_tokens, tokens)
  end

  private

  def builder
    @builder ||= CourseBuilder::BuildSong.new(nil, nil)
  end
end
