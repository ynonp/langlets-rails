require "test_helper"

class Activities::ListenActivityTest < ActiveSupport::TestCase
  setup do
    @language = languages(:english)
    Current.translation_language = @language
    @user = User.create!(email: "listen-activity@example.com", password: "password123", confirmed_at: Time.zone.now)
    @medium = Medium.create!(url: "https://www.youtube.com/watch?v=listen", language: @language)
    course = Course.create!(name: "Listen course", slug: "listen-course", main_media_url: @medium.url, language: @language, user: @user)
    lesson = Lesson.create!(course:, medium: @medium, user: @user, name: "Listen", slug: "listen", order: 1)
    @activity = Activities::ListenActivity.create!(lesson:, user: @user, order: 1)
    @activity.define_singleton_method(:video_params) { { start_timestamp: "00:10", end_timestamp: "00:20" } }
  end

  teardown { Current.reset }

  test "uses the native interactive player and word timing when every token is timed" do
    phrase = add_phrase("hello world", "00:10")
    add_token(phrase, 0, 4, "00:10.00")
    add_token(phrase, 6, 10, "00:10.50")
    @activity.phrases << phrase

    params = @activity.activity_params

    assert params[:video_player]
    assert params[:interactive_video_player]
    assert params[:preload_player]
    assert params[:word_timing]
  end

  test "falls back to phrase timing when any phrase token lacks a timestamp" do
    phrase = add_phrase("legacy words", "00:10")
    add_token(phrase, 0, 5, nil)
    add_token(phrase, 7, 11, nil)
    @activity.phrases << phrase

    refute @activity.activity_params[:word_timing]
  end

  private

  def add_phrase(text, timestamp)
    create_translated_phrase!(medium: @medium, l1: @language, text_l1: text, l2: @language, text_l2: "translation", timestamp:)
  end

  def add_token(phrase, start_index, end_index, start_timestamp)
    create_translated_token!(
      phrase:, language: @language, translation: "translation",
      l1_start_index: start_index, l1_end_index: end_index,
      l2_start_index: 0, l2_end_index: 10,
      index_type: :character_index, start_timestamp:, end_timestamp: start_timestamp
    )
  end
end
