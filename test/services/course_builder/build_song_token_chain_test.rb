require "test_helper"

class CourseBuilder::BuildSongTokenChainTest < ActiveSupport::TestCase
  Token = Struct.new(:part_of_speech, :original_text, :translation, :phrase_id)
  Phrase = Struct.new(:phrase_tokens)

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

  test "flashcards use content words from different phrases" do
    tokens = [
      Token.new("pronoun", "I", "yo", 1),
      Token.new("noun", "song", "canción", 1),
      Token.new("verb", "sing", "cantar", 1),
      Token.new("noun", "voice", "voz", 1),
      Token.new("verb", "dance", "bailar", 2),
      Token.new("noun", "heart", "corazón", 3),
      Token.new("adjective", "bright", "brillante", 4)
    ]

    selected = builder.send(:flashcard_tokens, tokens)

    assert_equal 5, selected.size
    assert selected.all? { |token| %w[noun verb adjective adverb].include?(token.part_of_speech) }
    assert selected.group_by(&:phrase_id).values.all? { |phrase_tokens| phrase_tokens.size <= 2 }
    assert_equal 4, selected.count { |token| %w[noun verb].include?(token.part_of_speech) }
  end

  test "flashcards exclude duplicate words and translations" do
    tokens = [
      Token.new("noun", "song", "canción", 1),
      Token.new("noun", "song", "melodía", 2),
      Token.new("noun", "tune", "canción", 3),
      Token.new("verb", "sing", "cantar", 4)
    ]

    selected = builder.send(:flashcard_tokens, tokens)

    assert_equal selected.map { |token| token.original_text.downcase }.uniq.size, selected.size
    assert_equal selected.map { |token| token.translation.downcase }.uniq.size, selected.size
  end

  test "word order phrases contain no more than ten phrase tokens" do
    phrases = [
      Phrase.new(Array.new(10) { Token.new }),
      Phrase.new(Array.new(11) { Token.new }),
      Phrase.new(Array.new(2) { Token.new }),
      Phrase.new([])
    ]

    selected = builder.send(:word_order_phrases, phrases)

    assert_equal [ phrases.first, phrases.third ], selected
  end

  test "word order is removed from the activity pool without two eligible phrases" do
    phrases = [
      Phrase.new(Array.new(11) { Token.new }),
      Phrase.new(Array.new(3) { Token.new })
    ]

    types = builder.send(:pooled_activity_types, { phrases: phrases })

    refute_includes types, :word_order
    assert_equal CourseBuilder::BuildSong::LESSON_ACTIVITY_POOL.size - 1, types.size
  end

  test "word order remains in the activity pool with two eligible phrases" do
    phrases = [ Phrase.new(Array.new(3) { Token.new }), Phrase.new(Array.new(10) { Token.new }) ]

    types = builder.send(:pooled_activity_types, { phrases: phrases })

    assert_includes types, :word_order
  end

  private

  def builder
    @builder ||= CourseBuilder::BuildSong.new(nil, nil)
  end
end
