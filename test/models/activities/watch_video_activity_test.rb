require "test_helper"

class Activities::WatchVideoActivityTest < ActiveSupport::TestCase
  test "uses the preloaded interactive video player" do
    activity = Activities::WatchVideoActivity.new
    lesson = Struct.new(:rtl_language, :media_language).new(false, "English")
    language = Struct.new(:rtl).new(false)
    phrase = Struct.new(:l2, :phrase_tokens).new(language, [])
    activity.define_singleton_method(:lesson) { lesson }
    activity.define_singleton_method(:ordered_phrases) { [phrase] }
    activity.define_singleton_method(:video_params) { {} }

    params = activity.activity_params

    assert params[:video_player]
    assert params[:interactive_video_player]
    assert params[:preload_player]
  end
end
