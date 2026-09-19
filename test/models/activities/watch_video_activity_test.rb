require "test_helper"

class Activities::WatchVideoActivityTest < ActiveSupport::TestCase
  test "uses the preloaded interactive video player" do
    activity = Activities::WatchVideoActivity.new
    lesson = Struct.new(:rtl_language, :media_language).new(false, "English")
    language = Struct.new(:rtl).new(false)
    phrase = Struct.new(:l1, :l2, :phrase_tokens).new(language, language, [])
    activity.define_singleton_method(:lesson) { lesson }
    activity.define_singleton_method(:ordered_phrases) { [phrase] }
    activity.define_singleton_method(:video_params) { {} }

    params = activity.activity_params

    assert params[:video_player]
    assert params[:interactive_video_player]
    assert params[:preload_player]
  end

  test "provides sentence playback boundaries for the lesson segment" do
    activity = Activities::WatchVideoActivity.new
    lesson = Struct.new(:rtl_language, :media_language).new(false, "English")
    language = Struct.new(:rtl).new(false)
    token = Struct.new(:start_timestamp, :end_timestamp).new("00:01.10", "00:02.50")
    first = Struct.new(:id, :l1, :l2, :phrase_tokens, :timestamp)
      .new(11, language, language, [ token ], "00:01.00")
    second = Struct.new(:id, :l1, :l2, :phrase_tokens, :timestamp)
      .new(12, language, language, [], "00:04.00")
    third = Struct.new(:id, :l1, :l2, :phrase_tokens, :timestamp)
      .new(13, language, language, [], "00:06.00")
    activity.define_singleton_method(:lesson) { lesson }
    activity.define_singleton_method(:ordered_phrases) { [ first, second, third ] }
    activity.define_singleton_method(:video_params) { {} }

    params = activity.activity_params

    assert_equal({ 11 => 2.5, 12 => 6.0 }, params[:sentence_ends])
  end
end
