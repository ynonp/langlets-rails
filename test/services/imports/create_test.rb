require "test_helper"
require "minitest/mock"

module Imports
  class CreateTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    VIDEO_ID = "kJQP7kiw5Fk".freeze
    CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

    setup do
      @user    = create_user("importer@example.com")
      @other   = create_user("other@example.com")
      @spanish = languages(:spanish)
      @english = languages(:english)
      @hebrew  = languages(:hebrew)
    end

    test "creates a course, charges one credit and queues the pipeline" do
      result = nil
      assert_enqueued_with(job: CreateCourseJob) do
        result = stub_video { call_create }
      end

      assert result.created?
      assert_equal 2, @user.reload.credit_balance

      request = result.import_request
      assert request.queued?
      assert request.charged?
      assert_equal VIDEO_ID, request.youtube_video_id
      assert_equal CANONICAL, request.youtube_url, "the URL should be stored canonicalised"
      assert_equal "Despacito", request.title

      course = result.course
      assert course.pending?
      assert_equal VIDEO_ID, course.youtube_video_id
      assert_equal @spanish, course.language
      assert_equal @english, course.translation_language
      assert_equal CreateSongProgress.sole, request.create_song_progress
    end

    # A pending course has no lessons — showing it on Home would offer a course
    # that can't be opened. CreateCourseJob enrolls on publish instead.
    test "does not put the course on Home until it is published" do
      result = stub_video { call_create }

      assert_equal 0, @user.enrollments.count
      assert result.course.pending?
    end

    test "a short link and a link with a timestamp import the same video once" do
      stub_video { call_create(url: "https://youtu.be/#{VIDEO_ID}") }

      second = stub_video { call_create(url: "https://www.youtube.com/watch?v=#{VIDEO_ID}&t=42") }

      assert second.already_queued?, "expected the second link to be recognised as the same video"
      assert_equal 2, @user.reload.credit_balance, "must not charge twice for one video"
      assert_equal 1, @user.import_requests.count
    end

    test "refuses to import when the balance is empty, without creating anything" do
      User.where(id: @user.id).update_all(credit_balance: 0)

      assert_raises(Credits::InsufficientCredits) { stub_video { call_create } }

      assert_equal 0, @user.reload.credit_balance
      assert_equal 0, @user.import_requests.count
      assert_equal 0, Course.where(youtube_video_id: VIDEO_ID).count, "no orphan course"
    end

    # The whole point of checking oEmbed before charging.
    test "a private or deleted video costs nothing" do
      Youtube::Oembed.stub(:fetch, ->(_url) { raise Youtube::Oembed::UnavailableVideo, "video is private" }) do
        assert_raises(Youtube::Oembed::UnavailableVideo) { call_create }
      end

      assert_equal 3, @user.reload.credit_balance
      assert_equal 0, @user.import_requests.count
    end

    test "rejects a language we don't teach, without charging" do
      assert_raises(UnsupportedLanguage) { stub_video { call_create(clip_language: "Klingon") } }
      assert_raises(UnsupportedLanguage) { stub_video { call_create(translation_language: "Klingon") } }

      assert_equal 3, @user.reload.credit_balance
    end

    test "an already published video is handed over free and enrolled" do
      published = publish_course!(user: @other)

      result = stub_video { call_create }

      assert result.deduped?
      assert_equal published, result.course
      assert_equal 3, @user.reload.credit_balance, "the Library is free"
      assert_equal 0, @user.import_requests.count

      enrollment = @user.enrollments.sole
      assert_equal published, enrollment.course
      assert enrollment.library?
    end

    test "dedupe is per language pair, not per video" do
      publish_course!(user: @other, translation_language: @english)

      result = stub_video { call_create(translation_language: "Hebrew") }

      assert result.created?, "Spanish->Hebrew is a different course from Spanish->English"
      assert_equal 2, @user.reload.credit_balance
    end

    # Two users importing the same video minutes apart. Without this, both create
    # a pending course and whichever publishes second violates
    # idx_courses_published_video_pair — failing an import the user paid for.
    test "a second user joins an in-flight import instead of starting a rival one" do
      first = stub_video { call_create(user: @user) }

      second = stub_video { call_create(user: @other) }

      assert second.joined?
      assert_equal first.course, second.course, "both must ride the same course"
      assert_equal 3, @other.reload.credit_balance, "the work is already paid for"
      assert_equal 1, Course.where(youtube_video_id: VIDEO_ID).count
      assert second.import_request.importing?
      assert_not second.import_request.charged?
    end

    test "a failed course does not block a fresh import" do
      stub_video { call_create }
      Course.sole.update!(status: :error)

      # The user's own request is still active, so clear it the way a failure would.
      @user.import_requests.update_all(status: ImportRequest.statuses[:failed])

      result = stub_video { call_create }

      assert result.created?, "an errored course must not wedge the video"
    end

    test "the same video for two translation languages gets distinct slugs" do
      first  = stub_video { call_create(translation_language: "English") }
      second = stub_video { call_create(translation_language: "Hebrew") }

      assert_not_equal first.course.slug, second.course.slug
      assert first.course.slug.present?
      assert second.course.slug.present?
    end

    test "the database refuses a duplicate active request for the same video" do
      stub_video { call_create }

      assert_raises(ActiveRecord::RecordNotUnique) do
        @user.import_requests.create!(
          youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
          clip_language: "Spanish", translation_language: "English", status: :queued
        )
      end
    end

    private

    def create_user(email)
      User.create!(email: email, password: "password123", confirmed_at: Time.zone.now)
    end

    def call_create(user: @user, url: CANONICAL, clip_language: "Spanish", translation_language: "English")
      Create.call(user: user, url: url, clip_language: clip_language, translation_language: translation_language)
    end

    def stub_video(title: "Despacito", &block)
      video = Youtube::Oembed::Video.new(
        video_id: VIDEO_ID,
        title: title,
        author_name: "Luis Fonsi",
        thumbnail_url: "https://i.ytimg.com/vi/#{VIDEO_ID}/hqdefault.jpg",
        canonical_url: CANONICAL
      )
      Youtube::Oembed.stub(:fetch, ->(_url) { video }, &block)
    end

    def publish_course!(user:, translation_language: @english)
      Course.create!(
        name: "Despacito", slug: "despacito-#{translation_language.iso_name}",
        main_media_url: CANONICAL, youtube_video_id: VIDEO_ID,
        language: @spanish, translation_language: translation_language,
        user: user, status: :published
      )
    end
  end
end
