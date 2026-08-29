require "test_helper"

class ActivitiesHelperTest < ActionView::TestCase
  test "timestamp_to_seconds with MM:SS format" do
    assert_equal 30.0, timestamp_to_seconds("00:30")
    assert_equal 60.0, timestamp_to_seconds("01:00")
    assert_equal 150.5, timestamp_to_seconds("02:30.5")
  end

  test "timestamp_to_seconds with MM:SS:mm format (milliseconds)" do
    assert_equal 30.2, timestamp_to_seconds("00:30:20")
    assert_equal 61.001, timestamp_to_seconds("01:01:001")
    assert_equal 120.5, timestamp_to_seconds("02:00:500")
    assert_equal 30.23, timestamp_to_seconds("00:30:23")
  end

  test "timestamp_to_seconds with zero values" do
    assert_equal 0.0, timestamp_to_seconds("00:00")
    assert_equal 0.0, timestamp_to_seconds("00:00:00")
  end

  test "timestamp_to_seconds with larger minute values" do
    assert_equal 3600.0, timestamp_to_seconds("60:00")
    assert_equal 3660.5, timestamp_to_seconds("61:00.5")
  end

  test "listen phrase segments preserve text and identify the timed missing token" do
    token_class = Struct.new(:id, :l1_start_index, :l1_end_index, :original_text, :start_timestamp_seconds)
    first = token_class.new(1, 0, 4, "hello", 10.0)
    missing = token_class.new(2, 6, 10, "world", 10.5)
    phrase = Struct.new(:text_l1, :phrase_tokens, :timestamp_seconds).new("hello world!", [ first, missing ], 10.0)

    segments = listen_phrase_segments(phrase, missing_token: missing)

    assert_equal "hello world!", segments.pluck(:text).join
    assert_equal "world", segments.find { |segment| segment[:missing] }[:text]
    assert_equal 10.5, segments.find { |segment| segment[:missing] }[:start]
  end

  test "phrase-level blank uses the selected token indexes, not every repeated word" do
    token = Struct.new(:l1_start_index, :l1_end_index, :original_text).new(4, 6, "one")
    phrase = Struct.new(:text_l1).new("one one")

    html = render_listen_phrase_with_blank(phrase, token)

    assert_match(/\Aone <span/, html)
    assert_includes html, 'data-answer="one"'
    assert_equal 1, html.scan("________").size
  end

  test "similar sounds fall back to the legacy phrase token array" do
    phrase = Struct.new(:text_l1, :similar_sounds).new("A Dios le pido", [])
    token = Struct.new(:l1_start_index, :l1_end_index, :similar_sound).new(14, 17, [ "nido", "olvido" ])

    assert_equal [ "nido", "olvido" ], similar_sounds_for_token(phrase, token)
  end

  test "flashcards include source video and phrase timing" do
    medium = Medium.create!(url: "https://www.youtube.com/watch?v=flashcard01", language: languages(:english))
    phrase = Phrase.create!(medium:, l1: languages(:english), text_l1: "hello world", timestamp: "00:10.00")
    Phrase.create!(medium:, l1: languages(:english), text_l1: "next phrase", timestamp: "00:13.50")
    token = phrase.phrase_tokens.create!(
      l1_start_index: 0,
      l1_end_index: 0,
      start_timestamp: "00:10.25",
      end_timestamp: "00:10.80"
    )
    token.resolved_translation = TokenTranslation.new(translation: "greeting")

    card = prepare_flashcards_for_tokens([ token ], [ "hello", "world", "next", "phrase" ]).first

    assert_equal "flashcard01", card[:video_id]
    assert_equal :youtube, card[:video_provider]
    assert_equal 10.0, card[:segment_start]
    assert_equal 13.5, card[:segment_end]
  end

  test "custom vocabulary flashcards have no video source" do
    user = User.create!(email: "custom-card@example.com", password: "password123", confirmed_at: Time.zone.now)
    phrase = Phrase.create!(user: user, l1: languages(:english), text_l1: "hello world")
    token = phrase.phrase_tokens.create!(
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index
    )
    token.resolved_translation = token.token_translations.create!(
      language: languages(:spanish),
      translation: "hola"
    )

    card = prepare_flashcards_for_tokens([ token ], [ "hello", "world" ]).first

    assert_nil card[:video_id]
    assert_nil card[:video_provider]
    assert_nil card[:segment_start]
    assert_nil card[:segment_end]
  end
end
