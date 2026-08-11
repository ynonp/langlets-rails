require "test_helper"

class TryVideoInfoTest < ActiveSupport::TestCase
  setup do
    @language = languages(:french)
    @user = User.create!(email: "try-video-info@example.com", password: "password123", confirmed_at: Time.zone.now)
    @url = "https://www.youtube.com/watch?v=tryinfo1234"
    @medium = Medium.create!(url: @url, language: @language)
    @course = Course.create!(
      name: "French example",
      slug: "french-example-info",
      main_media_url: @url,
      youtube_video_id: "tryinfo1234",
      language: @language,
      user: @user,
      status: :published
    )
    Lesson.create!(
      name: "Lesson 1",
      slug: "lesson-1",
      course: @course,
      medium: @medium,
      user: @user,
      order: 1,
      start_timestamp: "00:00",
      end_timestamp: "04:12"
    )
    @medium.phrases.create!(l1: @language, timestamp: "00:01", text_l1: "Bonjour le monde")
    @medium.phrases.create!(l1: @language, timestamp: "00:05", text_l1: "Bonjour encore")
    @video = VideoSource::Video.new(
      provider: :youtube,
      video_id: "tryinfo1234",
      title: @course.name,
      author_name: "Example author",
      thumbnail_url: "https://example.com/thumb.jpg",
      canonical_url: @url
    )
  end

  test "reports stored lesson metrics for an existing video" do
    info = TryVideoInfo.for(@video)

    assert_equal "French", info.language
    assert_equal "4:12", info.duration
    assert_equal 2, info.line_count
    assert_equal 4, info.unique_word_count
  end

  test "returns nil when the video has no stored course" do
    unknown = @video.with(video_id: "unknown12345", canonical_url: "https://www.youtube.com/watch?v=unknown12345")

    assert_nil TryVideoInfo.for(unknown)
  end
end
