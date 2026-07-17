require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "course YouTube video ID uses the canonical stored ID" do
    course = Course.new(
      main_media_url: "https://youtu.be/InDDvnq9elw",
      youtube_video_id: "InDDvnq9elw"
    )

    assert_equal "InDDvnq9elw", course_youtube_video_id(course)
  end

  test "course YouTube video ID falls back to parsing legacy course URLs" do
    course = Course.new(main_media_url: "https://youtu.be/InDDvnq9elw")

    assert_equal "InDDvnq9elw", course_youtube_video_id(course)
  end
end
