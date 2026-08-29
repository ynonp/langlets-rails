require "test_helper"

module Vocabulary
  # The word a user types in themselves. The interesting part is the span: the
  # picker reports whitespace-token indexes, and this has to land them on the
  # right characters of the stored phrase — including when the selection sweeps
  # up punctuation or spans several words.
  class CustomEntryTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(email: "custom@example.com", password: "password123", confirmed_at: Time.zone.now)
      @spanish = languages(:spanish)
      @english = languages(:english)
    end

    def add(sentence:, range:, translation: "meaning", language: nil)
      CustomEntry.new(user: @user, sentence: sentence, language: language || @spanish,
                      token_range: range, translation: translation,
                      translation_language: @english).call
    end

    test "stores the picked word as a span inside the phrase" do
      saved = add(sentence: "no queda tiempo", range: 2..2)
      entry = Entry.new(saved)

      assert_equal "tiempo", entry.word
      assert_equal "no queda tiempo", entry.context
      assert_equal "no queda ", entry.before
      assert_equal "tiempo", entry.mark
      assert_equal "", entry.after
      assert_equal "meaning", entry.translation
    end

    test "a multi-word pick is kept as one span, not several entries" do
      entry = Entry.new(add(sentence: "hay que darse prisa ahora", range: 2..3))

      assert_equal "darse prisa", entry.word
      assert_equal "hay que ", entry.before
      assert_equal " ahora", entry.after
      assert_equal 1, @user.phrase_token_users.count
    end

    test "punctuation the selection sweeps up is trimmed off the saved word" do
      entry = Entry.new(add(sentence: "rápido, gira a la izquierda", range: 0..0))

      assert_equal "rápido", entry.word
      assert_equal "rápido", entry.mark
      assert_equal ", gira a la izquierda", entry.after
    end

    test "runs of whitespace are normalised so the span still lands correctly" do
      entry = Entry.new(add(sentence: "  no    queda\n tiempo  ", range: 2..2))

      assert_equal "no queda tiempo", entry.context
      assert_equal "tiempo", entry.word
    end

    test "the same word in two phrases stays two separate entries" do
      first = Entry.new(add(sentence: "no queda tiempo", range: 2..2, translation: "time left"))
      second = Entry.new(add(sentence: "hace buen tiempo", range: 2..2, translation: "weather"))

      assert_equal 2, @user.phrase_token_users.count
      assert_equal "tiempo", first.word
      assert_equal "tiempo", second.word
      assert_equal "time left", first.translation
      assert_equal "weather", second.translation
    end

    test "custom words are labelled as the user's own, not as a course" do
      entry = Entry.new(add(sentence: "no queda tiempo", range: 2..2))

      assert entry.custom?
      assert_equal "Added by you", entry.source
    end

    test "one synthetic medium per user and language holds every typed phrase" do
      add(sentence: "no queda tiempo", range: 2..2)
      add(sentence: "hace buen tiempo", range: 2..2)

      media = @user.phrase_token_users.map { |row| row.phrase_token.phrase.medium }.uniq
      assert_equal 1, media.size
      assert_equal "langlets://custom-vocabulary/#{@user.id}", media.first.url
      # It has no lessons, which is how the list knows these are not from a course.
      assert_empty media.first.lessons
    end

    test "a custom word is practised, so it reaches the next review" do
      add(sentence: "no queda tiempo", range: 2..2)

      tokens = ReviewLessonBuilder.new(@user, language_code: @spanish.iso_name).fetch_tokens
      assert_equal 1, tokens.size
      assert_equal "tiempo", tokens.first.original_text
    end

    test "a blank phrase, a missing pick and a blank translation are each refused" do
      assert_raises(CustomEntry::Error) { add(sentence: "   ", range: 0..0) }
      assert_raises(CustomEntry::Error) { add(sentence: "no queda tiempo", range: nil) }
      assert_raises(CustomEntry::Error) { add(sentence: "no queda tiempo", range: 2..2, translation: " ") }
      assert_equal 0, @user.phrase_token_users.count
    end

    test "a pick that lands entirely on punctuation is refused" do
      assert_raises(CustomEntry::Error) { add(sentence: "no queda — tiempo", range: 2..2) }
      assert_equal 0, @user.phrase_token_users.count
    end

    test "a pick past the end of the phrase is refused rather than saved wrong" do
      assert_raises(CustomEntry::Error) { add(sentence: "no queda tiempo", range: 9..9) }
      assert_equal 0, @user.phrase_token_users.count
    end
  end
end
