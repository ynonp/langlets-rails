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

    test "creates a course and queues the pipeline, to be paid for on delivery" do
      result = nil
      assert_enqueued_with(job: CreateCourseJob) do
        result = stub_video { call_create }
      end

      assert result.created?
      assert_equal 1, result.cost, "quoted up front"
      assert_equal 3, @user.reload.credit_balance, "and taken by Channel#publish!, not here"

      request = result.import_request
      assert request.queued?
      assert_equal VIDEO_ID, request.youtube_video_id
      assert_equal CANONICAL, request.youtube_url, "the URL should be stored canonicalised"
      assert_equal "Despacito", request.title

      course = result.course
      assert course.pending?
      assert_equal VIDEO_ID, course.youtube_video_id
      assert_equal @spanish, course.language
      assert course.course_translations.exists?(language: @english)
      assert_equal CreateSongProgress.sole, request.create_song_progress
    end

    test "creates a provisional request and queues language detection without charging" do
      result = nil
      assert_enqueued_with(job: DetectImportLanguageJob) do
        result = stub_video do
          Create.call(user: @user, url: CANONICAL, translation_language: "English")
        end
      end

      request = result.import_request
      assert request.detecting?
      assert_nil request.clip_language
      assert_nil request.course
      assert_nil request.create_song_progress.clip_language
      assert_equal 3, @user.reload.credit_balance
    end

    test "dedupes provisional requests before their language is known" do
      first = stub_video do
        Create.call(user: @user, url: CANONICAL, translation_language: "English")
      end
      second = stub_video do
        Create.call(user: @user, url: CANONICAL, translation_language: "English")
      end

      assert second.already_queued?
      assert_equal first.import_request, second.import_request
      assert_equal 1, @user.import_requests.count
      assert_equal 3, @user.reload.credit_balance
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
      assert_equal 0, second.cost, "one publication, one charge"
      assert_equal 1, @user.import_requests.count
    end

    # Nothing is charged here, but running a pipeline for a course the user will
    # not be able to take delivery of helps nobody — least of all them.
    test "refuses to import when the balance is empty, without creating anything" do
      User.where(id: @user.id).update_all(credit_balance: 0)

      assert_raises(Credits::InsufficientCredits) { stub_video { call_create } }

      assert_equal 0, @user.reload.credit_balance
      assert_equal 0, @user.import_requests.count
      assert_equal 0, Course.where(youtube_video_id: VIDEO_ID).count, "no orphan course"
    end

    # One credit cannot buy three courses. Every import in flight is going to want
    # one when it lands, so the guard counts them rather than only the new one.
    test "refuses a third import when only two credits are left to deliver them" do
      User.where(id: @user.id).update_all(credit_balance: 2)

      stub_video(video_id: "aaaaaaaaaaa") { call_create(url: "https://www.youtube.com/watch?v=aaaaaaaaaaa") }
      stub_video(video_id: "bbbbbbbbbbb") { call_create(url: "https://www.youtube.com/watch?v=bbbbbbbbbbb") }

      assert_raises(Credits::InsufficientCredits) do
        stub_video(video_id: "ccccccccccc") { call_create(url: "https://www.youtube.com/watch?v=ccccccccccc") }
      end
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

    # The rule the whole design turns on: a course somebody else built is not
    # yours until it is in your channel, and putting it there costs what building
    # it would have. No pipeline runs, so it happens on the spot.
    test "importing a course somebody else built publishes it into your channel for one credit" do
      published = publish_course!(user: @other)

      result = stub_video { call_create }

      assert result.adopted?
      assert_equal published, result.course
      assert_equal 1, result.cost
      assert_equal 2, @user.reload.credit_balance
      assert @user.default_channel.channel_items.exists?(course: published)

      request = @user.import_requests.sole
      assert request.ready?, "nothing to wait for"
      assert_equal published, request.course

      enrollment = @user.enrollments.sole
      assert_equal published, enrollment.course
      assert enrollment.imported?, "they asked for this course themselves"
    end

    test "importing a course already in your own channel changes and costs nothing" do
      published = publish_course!(user: @other)
      publish_privately(published, owner: @user)
      before = @user.reload.credit_balance

      result = stub_video { call_create }

      assert result.deduped?
      assert_equal published, result.course
      assert_equal 0, result.cost
      assert_equal before, @user.reload.credit_balance
      assert_equal 0, @user.import_requests.count
      assert @user.enrollments.sole.imported?
    end

    # It is one course in one channel, however many times they ask.
    test "importing the same course twice charges once" do
      publish_course!(user: @other)

      stub_video { call_create }
      second = stub_video { call_create }

      assert second.deduped?
      assert_equal 2, @user.reload.credit_balance
      assert_equal 1, @user.credit_ledger_entries.import_spend.count
    end

    test "a missing language creates translation work on the shared course" do
      published = publish_course!(user: @other, translation_language: @english)

      result = nil
      assert_enqueued_with(job: AddCourseTranslationJob) do
        result = stub_video { call_create(translation_language: "Hebrew") }
      end

      assert result.created?
      assert_equal published, result.course
      assert_equal 1, result.cost, "not in their channel yet, so it is an ordinary import"
      assert_equal 3, @user.reload.credit_balance, "and charged when it publishes"
      assert published.course_translations.pending.exists?(language: @hebrew)
      assert_equal CreateSongProgress.sole, published.reload.create_song_progress
    end

    # The credit bought the course, and a course that gains a language is still
    # the one course they bought — Channel#publish! finds its item already there.
    test "a second language for a course already in your channel is free" do
      published = publish_course!(user: @other, translation_language: @english)
      publish_privately(published, owner: @user)
      before = @user.reload.credit_balance

      result = stub_video { call_create(translation_language: "Hebrew") }

      assert result.created?
      assert_equal 0, result.cost

      published.course_translations.find_by(language: @hebrew).ready!
      Settlement.complete!(result.import_request)

      assert_equal before, @user.reload.credit_balance
    end

    # Two users importing the same video minutes apart. Without this, both create
    # a pending course and whichever publishes second violates
    # idx_courses_published_video_pair — failing an import the user paid for.
    test "a second user joins an in-flight import instead of starting a rival one" do
      first = stub_video { call_create(user: @user) }

      second = stub_video { call_create(user: @other) }

      assert second.joined?
      assert_equal first.course, second.course, "both must ride the same course"
      assert_equal 1, Course.where(youtube_video_id: VIDEO_ID).count
      assert second.import_request.importing?

      # Sharing the run is not a discount: the rider gets their own publication
      # and pays for it when the run lands, exactly like the first importer.
      assert_equal 1, second.cost
      assert_equal 3, @other.reload.credit_balance, "not yet — nothing has published"

      first.course.published!
      Settlement.complete!(second.import_request)
      assert_equal 2, @other.reload.credit_balance
    end

    test "a failed course does not block a fresh import" do
      stub_video { call_create }
      Course.sole.update!(status: :error)

      # The user's own request is still active, so clear it the way a failure would.
      @user.import_requests.update_all(status: ImportRequest.statuses[:failed])

      result = stub_video { call_create }

      assert result.created?, "an errored course must not wedge the video"
    end

    test "the same video for two translation languages shares one slug" do
      first  = stub_video { call_create(translation_language: "English") }
      second = stub_video { call_create(translation_language: "Hebrew") }

      assert_equal first.course.slug, second.course.slug
      assert_equal first.course, second.course
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

    # Pro is not a stocked balance: the subscriber's course is published into a
    # ProChannel, and ProChannel#publish! does not charge. Nothing in the credit
    # machinery runs at all.
    test "a Pro import runs without moving a credit, all the way through" do
      go_pro!

      result = stub_video { call_create }
      assert result.created?
      assert_equal 0, result.cost
      assert_not result.charged?

      result.course.published!
      Settlement.complete!(result.import_request)

      assert_equal 3, @user.reload.credit_balance, "Pro imports are not metered"
      assert_equal 0, @user.credit_ledger_entries.import_spend.count
      assert @user.pro_channel.channel_items.exists?(course: result.course)
    end

    # A subscriber who could import a new video but not add a language to an
    # existing one would be a very confusing bug to be on the wrong side of. The
    # single override in ProChannel is what makes it impossible.
    test "a Pro translation import runs without moving a credit" do
      go_pro!
      publish_course!(user: @other, translation_language: @english)

      result = nil
      assert_enqueued_with(job: AddCourseTranslationJob) do
        result = stub_video { call_create(translation_language: "Hebrew") }
      end

      assert result.created?
      assert_equal 0, result.cost
      assert_equal 3, @user.reload.credit_balance
    end

    # Adoption is the path with no pipeline at all, so it is the one that could
    # most easily have grown its own pricing rule. It has not.
    test "a Pro subscriber adopts an existing course for nothing" do
      go_pro!
      published = publish_course!(user: @other)

      result = stub_video { call_create }

      assert result.adopted?
      assert_equal 0, result.cost
      assert_equal 3, @user.reload.credit_balance
      assert @user.reload.pro_channel.channel_items.exists?(course: published)
    end

    # The balance guard is the only thing standing between a free account and
    # unlimited imports, so Pro has to bypass it rather than lean on a stocked
    # balance.
    test "a Pro user with an empty balance can still import" do
      go_pro!
      User.where(id: @user.id).update_all(credit_balance: 0)

      result = stub_video { call_create }

      assert result.created?
      assert_equal 0, @user.reload.credit_balance
    end

    test "a settled Pro import lands on Home as the user's own import" do
      go_pro!
      result = stub_video { call_create }
      result.course.update!(status: :published)

      Settlement.complete!(result.import_request)

      assert @user.enrollments.sole.imported?
    end

    private

    def create_user(email)
      User.create!(email: email, password: "password123", confirmed_at: Time.zone.now)
    end

    def go_pro!(user: @user)
      Subscription.create!(
        user: user,
        product_id: Apple::SubscriptionPlans.yearly.product_id,
        plan: :yearly, status: :active,
        original_transaction_id: "2000000#{user.id}",
        purchased_at: Time.zone.now, expires_at: 1.year.from_now
      )
      user.reload
    end

    def call_create(user: @user, url: CANONICAL, clip_language: "Spanish", translation_language: "English")
      Create.call(user: user, url: url, clip_language: clip_language, translation_language: translation_language)
    end

    def stub_video(title: "Despacito", video_id: VIDEO_ID, &block)
      video = Youtube::Oembed::Video.new(
        video_id: video_id,
        title: title,
        author_name: "Luis Fonsi",
        thumbnail_url: "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg",
        canonical_url: "https://www.youtube.com/watch?v=#{video_id}"
      )
      Youtube::Oembed.stub(:fetch, ->(_url) { video }, &block)
    end

    def publish_course!(user:, translation_language: @english)
      Course.create!(
        name: "Despacito", slug: "despacito-#{translation_language.iso_name}",
        main_media_url: CANONICAL, youtube_video_id: VIDEO_ID,
        language: @spanish,
        user: user, status: :published
      ).tap do |course|
        course.course_translations.create!(language: translation_language, name: "Despacito", status: :ready)
      end
    end
  end
end
