require "test_helper"
require "minitest/mock"

module Imports
  # Preview exists to answer, without charging, what Create will do a moment
  # later. So most of these tests are really one test asked twice: preview and
  # create, same setup, do they agree? A preview that quotes a credit for
  # something Create hands over free is a bug the user pays for.
  class PreviewTest < ActiveSupport::TestCase
    VIDEO_ID = "kJQP7kiw5Fk".freeze
    CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

    setup do
      @user    = create_user("previewer@example.com")
      @other   = create_user("other@example.com")
      @spanish = languages(:spanish)
      @english = languages(:english)
      @hebrew  = languages(:hebrew)
    end

    test "a fresh video is importable for one credit" do
      preview = stub_video { call_preview }

      assert preview.importable?
      assert_equal 1, preview.cost
      assert_equal "Despacito", preview.video.title
    end

    test "previewing charges nothing and writes nothing" do
      stub_video { call_preview }

      assert_equal 3, @user.reload.credit_balance
      assert_equal 0, @user.import_requests.count
      assert_equal 0, Course.where(youtube_video_id: VIDEO_ID).count
      assert_equal 0, CreateSongProgress.count
    end

    # Somebody else built it, so there is no pipeline to run — but it still has to
    # be published into this user's channel, and that publication is the thing a
    # credit buys. Quoting it free would be quoting the pipeline, which nobody is
    # selling.
    test "a course somebody else already built still costs a credit" do
      published = publish_course!(user: @other)

      preview = stub_video { call_preview }

      assert preview.importable?
      assert_equal published, preview.course
      assert_equal 1, preview.cost
    end

    # The one free duplicate: it is already in their channel, so Approve would
    # publish nothing. The useful button is Open.
    test "a course already in the user's own channel is free and reports as in the library" do
      published = publish_course!(user: @other)
      publish_privately(published, owner: @user)

      preview = stub_video { call_preview }

      assert preview.in_library?
      assert_equal published, preview.course
      assert preview.free?
    end

    # Published for English but not Hebrew still runs a pipeline, and the course
    # is not in their channel yet, so it is priced like any other import.
    test "published without the user's translation still costs a credit" do
      publish_course!(user: @other, translation_language: @english)

      preview = stub_video { call_preview(translation_language: "Hebrew") }

      assert preview.importable?
      assert_equal 1, preview.cost
    end

    # A second language for a course they already have publishes nothing new, and
    # Channel#publish! only charges for a publication.
    test "a second language on a course they already have is free" do
      published = publish_course!(user: @other, translation_language: @english)
      publish_privately(published, owner: @user)

      preview = stub_video { call_preview(translation_language: "Hebrew") }

      assert preview.importable?
      assert preview.free?
    end

    test "the user's own in-flight request reports as already importing" do
      stub_video { call_create }

      preview = stub_video { call_preview }

      assert preview.in_queue?
      assert_equal @user.import_requests.sole, preview.import_request
    end

    # Riding along on somebody's run saves the pipeline, not the credit: the rider
    # still gets their own publication, so the button must say so.
    test "someone else's in-flight import is quoted at the full price" do
      stub_video { call_create(user: @other) }

      preview = stub_video { call_preview(user: @user) }

      assert preview.importable?
      assert_equal 1, preview.cost
    end

    # §4: the duplicate check runs first, so a video the user already has never
    # renders the paywall — even at a zero balance.
    test "a broke user still gets the library state, not an insufficient-credits one" do
      published = publish_course!(user: @other)
      publish_privately(published, owner: @user)
      User.where(id: @user.id).update_all(credit_balance: 0)

      preview = stub_video { call_preview }

      assert preview.in_library?
      assert preview.free?
    end

    # The balance is the view's business — Preview reports cost, not affordability
    # — but a broke user must still get a fully rendered card to want (§5.1).
    test "an empty balance does not stop a video resolving" do
      User.where(id: @user.id).update_all(credit_balance: 0)

      preview = stub_video { call_preview }

      assert preview.importable?
      assert_equal 1, preview.cost
      assert_equal "Despacito", preview.video.title
    end

    test "an unavailable video raises rather than previewing" do
      Youtube::Oembed.stub(:fetch, ->(_url) { raise Youtube::Oembed::UnavailableVideo, "private" }) do
        assert_raises(Youtube::Oembed::UnavailableVideo) { call_preview }
      end
    end

    test "rejects a language we don't teach" do
      assert_raises(UnsupportedLanguage) { stub_video { call_preview(clip_language: "Klingon") } }
    end

    # The agreement that matters, stated directly. A fresh import is charged when
    # it publishes, so the balance only moves once the course is settled.
    test "preview's quoted cost matches what create eventually charges" do
      before = @user.reload.credit_balance
      preview = stub_video { call_preview }

      result = stub_video { call_create }
      assert_equal before, @user.reload.credit_balance, "not charged for a course that does not exist yet"

      result.course.published!
      Imports::Settlement.complete!(result.import_request)

      assert_equal preview.cost, before - @user.reload.credit_balance
    end

    # The quote is about the whole import, and a queued one is charged when it
    # publishes rather than when it is asked for, so compare across the settlement
    # rather than across the call.
    test "preview's quoted cost matches what an adopted course actually costs" do
      publish_course!(user: @other)

      before = @user.reload.credit_balance
      preview = stub_video { call_preview }
      result = stub_video { call_create }

      assert result.adopted?
      assert_equal preview.cost, before - @user.reload.credit_balance
      assert_equal 1, preview.cost
    end

    test "preview's quoted cost matches what a rider is eventually charged" do
      stub_video { call_create(user: @other) }

      before = @user.reload.credit_balance
      preview = stub_video { call_preview(user: @user) }
      result = stub_video { call_create(user: @user) }

      assert result.joined?
      assert_equal before, @user.reload.credit_balance, "not yet — it has not been published"

      Imports::Settlement.complete!(result.import_request.tap { result.course.published! })
      assert_equal preview.cost, before - @user.reload.credit_balance
    end

    private

    def create_user(email)
      User.create!(email: email, password: "password123", confirmed_at: Time.zone.now)
    end

    def call_preview(user: @user, url: CANONICAL, clip_language: "Spanish", translation_language: "English")
      Preview.call(user: user, url: url, clip_language: clip_language, translation_language: translation_language)
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
        language: @spanish, user: user, status: :published
      ).tap do |course|
        course.course_translations.create!(language: translation_language, name: "Despacito", status: :ready)
      end
    end
  end
end
