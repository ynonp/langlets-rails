require "test_helper"

class RefreshTiktokThumbnailUrlsJobTest < ActiveJob::TestCase
  TIKTOK_ID = "6718335390845095173".freeze
  TIKTOK_URL = "https://www.tiktok.com/@scout2015/video/#{TIKTOK_ID}".freeze
  OLD_THUMBNAIL = "https://p16-sign-va.tiktokcdn.com/old?x-expires=1".freeze
  NEW_THUMBNAIL = "https://p16-sign-va.tiktokcdn.com/new?x-expires=2".freeze

  setup do
    @user = User.create!(
      email: "thumbnail-refresh@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
  end

  test "refreshes stored TikTok thumbnail URLs" do
    course = create_course(TIKTOK_URL, thumbnail_url: OLD_THUMBNAIL)

    VideoSource.stub(:fetch, ->(_url) { tiktok_video }) do
      RefreshTiktokThumbnailUrlsJob.perform_now
    end

    assert_equal NEW_THUMBNAIL, course.reload[:thumbnail_url]
  end

  test "does not fetch or change YouTube thumbnails" do
    course = create_course(
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      thumbnail_url: "https://example.com/custom.jpg"
    )

    VideoSource.stub(:fetch, ->(_url) { flunk "YouTube must not be fetched" }) do
      RefreshTiktokThumbnailUrlsJob.perform_now
    end

    assert_equal "https://example.com/custom.jpg", course.reload[:thumbnail_url]
  end

  test "keeps the stored URL when oEmbed returns no thumbnail" do
    course = create_course(TIKTOK_URL, thumbnail_url: OLD_THUMBNAIL)
    video = tiktok_video(thumbnail_url: nil)

    VideoSource.stub(:fetch, ->(_url) { video }) do
      RefreshTiktokThumbnailUrlsJob.perform_now
    end

    assert_equal OLD_THUMBNAIL, course.reload[:thumbnail_url]
  end

  test "one failed lookup does not prevent another course from refreshing" do
    failed_course = create_course(TIKTOK_URL, thumbnail_url: OLD_THUMBNAIL)
    other_id = "7234567890123456789"
    refreshed_course = create_course(
      "https://www.tiktok.com/@another/video/#{other_id}",
      thumbnail_url: OLD_THUMBNAIL
    )

    fetch = lambda do |url|
      raise VideoSource::UnavailableVideo, "video is private" if url == TIKTOK_URL

      tiktok_video(video_id: other_id, canonical_url: url)
    end

    VideoSource.stub(:fetch, fetch) { RefreshTiktokThumbnailUrlsJob.perform_now }

    assert_equal OLD_THUMBNAIL, failed_course.reload[:thumbnail_url]
    assert_equal NEW_THUMBNAIL, refreshed_course.reload[:thumbnail_url]
  end

  test "keeps the stored URL when oEmbed resolves to a different video" do
    course = create_course(TIKTOK_URL, thumbnail_url: OLD_THUMBNAIL)

    VideoSource.stub(:fetch, ->(_url) { tiktok_video(video_id: "9999999999999999999") }) do
      RefreshTiktokThumbnailUrlsJob.perform_now
    end

    assert_equal OLD_THUMBNAIL, course.reload[:thumbnail_url]
  end

  private

  def create_course(url, thumbnail_url:)
    Course.create!(
      name: "Thumbnail refresh",
      slug: "thumbnail-refresh-#{SecureRandom.hex(4)}",
      main_media_url: url,
      thumbnail_url: thumbnail_url,
      user: @user,
      status: :published
    )
  end

  def tiktok_video(video_id: TIKTOK_ID, thumbnail_url: NEW_THUMBNAIL, canonical_url: TIKTOK_URL)
    VideoSource::Video.new(
      provider: :tiktok,
      video_id: video_id,
      title: "Scout and Suki",
      author_name: "scout2015",
      thumbnail_url: thumbnail_url,
      canonical_url: canonical_url
    )
  end
end
