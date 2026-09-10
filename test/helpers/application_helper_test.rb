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

  test "next activity finish links retain custom actions" do
    html = link_to_next_activity(
      "Next",
      finish_course_lesson_path("course", "lesson"),
      data: { action: "click->match-activity#continue" }
    )

    assert_includes html, 'data-action="click-&gt;match-activity#continue"'
    assert_includes html, 'data-turbo-frame="_top"'
    assert_includes html, 'data-turbo-action="replace"'
  end
end
