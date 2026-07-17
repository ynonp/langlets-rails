require "test_helper"

# The Library's canonical-course invariant: one published course per video per
# language pair. Held by idx_courses_published_video_pair rather than by
# application code, so that two importers racing on the same video can't both
# publish.
class CourseDedupeTest < ActiveSupport::TestCase
  VIDEO_ID = "kJQP7kiw5Fk".freeze

  setup do
    @user    = User.create!(email: "dedupe@example.com", password: "password123", confirmed_at: Time.zone.now)
    @other   = User.create!(email: "dedupe2@example.com", password: "password123", confirmed_at: Time.zone.now)
    @spanish = languages(:spanish)
    @english = languages(:english)
    @hebrew  = languages(:hebrew)
  end

  test "two users cannot both publish the same video for the same language pair" do
    publish!(user: @user, slug: "first")

    assert_raises(ActiveRecord::RecordNotUnique) do
      publish!(user: @other, slug: "second")
    end
  end

  test "the same video can be published for different translation languages" do
    es_en = publish!(user: @user,  slug: "spanish-english", translation_language: @english)
    es_he = publish!(user: @other, slug: "spanish-hebrew",  translation_language: @hebrew)

    assert_not_equal es_en.id, es_he.id
  end

  # Scoped to published so a failed or in-flight import doesn't wedge the video
  # for everyone else.
  test "unpublished courses for the same video do not collide" do
    publish!(user: @user, slug: "published-one")

    assert_nothing_raised do
      build_course(user: @other, slug: "pending-one").tap { |c| c.status = :pending }.save!
      build_course(user: @other, slug: "errored-one").tap { |c| c.status = :error }.save!
    end
  end

  test "different videos never collide" do
    publish!(user: @user, slug: "video-one", video_id: "aaaaaaaaaaa")

    assert_nothing_raised do
      publish!(user: @other, slug: "video-two", video_id: "bbbbbbbbbbb")
    end
  end

  # The name index was dropped: two people can import different videos that happen
  # to share a title.
  test "two courses may share a name" do
    publish!(user: @user,  slug: "one", video_id: "aaaaaaaaaaa", name: "Cuatro Vientos")

    assert_nothing_raised do
      publish!(user: @other, slug: "two", video_id: "bbbbbbbbbbb", name: "Cuatro Vientos")
    end
  end

  private

  def build_course(user:, slug:, video_id: VIDEO_ID, translation_language: @english, name: nil)
    Course.new(
      name: name || "Course #{slug}",
      slug: slug,
      main_media_url: "https://www.youtube.com/watch?v=#{video_id}",
      youtube_video_id: video_id,
      language: @spanish,
      translation_language: translation_language,
      user: user
    )
  end

  def publish!(**args)
    build_course(**args).tap do |course|
      course.status = :published
      course.save!
    end
  end
end
