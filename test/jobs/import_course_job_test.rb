require "test_helper"

# The local/manual path starts temporary HTTP servers and then calls this job
# synchronously. It predates the queue and does its own oEmbed lookup, so the
# provider handling here is separate from Imports::Create's.
class ImportCourseJobTest < ActiveJob::TestCase
  TIKTOK_ID = "6718335390845095173".freeze
  TIKTOK_URL = "https://www.tiktok.com/@scout2015/video/#{TIKTOK_ID}".freeze
  TIKTOK_THUMB = "https://p16-sign-va.tiktokcdn.com/obj/abc?x-expires=1".freeze
  YOUTUBE_ID = "kJQP7kiw5Fk".freeze
  YOUTUBE_URL = "https://www.youtube.com/watch?v=#{YOUTUBE_ID}".freeze

  setup do
    @user = User.create!(
      email: "local-import@example.com", password: "password123", confirmed_at: Time.zone.now
    )
  end

  # Without this the course renders no cover at all: TikTok's are signed CDN
  # URLs that cannot be derived from the URL the way YouTube's can.
  test "stores the TikTok cover oEmbed returned" do
    course = run_job(TIKTOK_URL, video_for(:tiktok))

    assert_equal TIKTOK_THUMB, course[:thumbnail_url]
    assert_equal TIKTOK_THUMB, course.thumbnail_url
    assert course.tiktok?
    assert_equal TIKTOK_ID, course.video_id
  end

  # Left NULL on purpose — derivation covers YouTube for free, which is why the
  # column needed no backfill.
  test "leaves the column empty for YouTube and derives instead" do
    course = run_job(YOUTUBE_URL, video_for(:youtube))

    assert_nil course[:thumbnail_url]
    assert_equal "https://img.youtube.com/vi/#{YOUTUBE_ID}/hqdefault.jpg", course.thumbnail_url
  end

  # This job runs after the pipeline has already done the expensive work, so a
  # failed lookup must not throw that away.
  test "a failed oEmbed lookup still produces a course" do
    unavailable = ->(_url) { raise VideoSource::UnavailableVideo, "video is private" }
    course = VideoSource.stub(:fetch, unavailable) { perform(TIKTOK_URL) }

    assert course.persisted?
    assert course.published?
    assert_nil course.thumbnail_url
  end

  test "keeps the clip and translation languages distinct" do
    built_in = nil
    course = run_job(TIKTOK_URL, video_for(:tiktok)) do |translation_language|
      built_in = translation_language
    end

    assert_equal languages(:spanish), course.language
    assert_equal languages(:english), built_in
  end

  private

  def video_for(provider)
    if provider == :tiktok
      VideoSource::Video.new(
        provider: :tiktok, video_id: TIKTOK_ID, title: "Scout and Suki",
        author_name: "scout2015", thumbnail_url: TIKTOK_THUMB, canonical_url: TIKTOK_URL
      )
    else
      VideoSource::Video.new(
        provider: :youtube, video_id: YOUTUBE_ID, title: "Despacito",
        author_name: "Luis Fonsi",
        thumbnail_url: "https://i.ytimg.com/vi/#{YOUTUBE_ID}/hqdefault.jpg",
        canonical_url: YOUTUBE_URL
      )
    end
  end

  def run_job(url, video, &on_build)
    VideoSource.stub(:fetch, ->(_url) { video }) { perform(url, &on_build) }
  end

  def perform(url, &on_build)
    progress = CreateSongProgress.create!(
      youtubeurl: url, clip_language: "Spanish", data: {}
    )

    # BuildSong needs a fully populated pipeline blob; this job's provider
    # handling is what's under test, so the build is stubbed out.
    builder = Object.new
    builder.define_singleton_method(:call) { |language| on_build&.call(language) }

    # Delivery is a job now (DeliverNotificationJob), so nothing is mailed
    # inline and there is no mailer left to stub out.
    CourseBuilder::BuildSong.stub(:new, ->(*) { builder }) do
      ImportCourseJob.perform_now(progress.id, @user.id, languages(:english).id)
    end

    Course.find_by!(main_media_url: url, user: @user)
  end
end
