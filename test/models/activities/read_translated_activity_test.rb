require "test_helper"

class Activities::ReadTranslatedActivityTest < ActiveSupport::TestCase
  test "activity_params exposes only the translated phrases, no video" do
    activity = Activities::ReadTranslatedActivity.new
    language = Struct.new(:rtl).new(true)
    phrase = Struct.new(:l2, :phrase_tokens).new(language, [])
    activity.define_singleton_method(:ordered_phrases) { [phrase] }

    params = activity.activity_params

    assert_equal [phrase], params[:phrases]
    assert params[:l2_rtl]
    assert_nil params[:video_player]
  end
end
