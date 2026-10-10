require "test_helper"

class DetectImportLanguageJobTest < ActiveJob::TestCase
  test "enqueues only after the import transaction commits" do
    assert DetectImportLanguageJob.enqueue_after_transaction_commit
  end

  VIDEO_ID = "kJQP7kiw5Fk".freeze
  CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  setup do
    @user = User.create!(email: "detect-job@example.com", password: "password123", confirmed_at: Time.zone.now)
    @spanish = languages(:spanish)
    @english = languages(:english)
    @hebrew = languages(:hebrew)
    @video = Youtube::Oembed::Video.new(
      video_id: VIDEO_ID,
      title: "Despacito",
      author_name: "Luis Fonsi",
      thumbnail_url: "https://i.ytimg.com/vi/#{VIDEO_ID}/hqdefault.jpg",
      canonical_url: CANONICAL
    )
  end

  test "promotes the provisional request and queues course creation" do
    request = create_provisional_request
    detected_data = { "lyric_lines" => [ "hola" ], "stt_words" => [ { "text" => "hola" } ] }

    assert_enqueued_with(job: CreateCourseJob) do
      CreateSongProgress.stub(:detect_language, [ @spanish, detected_data ]) do
        Imports::VideoPreflight.stub(:call, ->(*) { flunk "promotion must not repeat duration preflight" }) do
          Youtube::Oembed.stub(:fetch, @video) do
            DetectImportLanguageJob.perform_now(request.id)
          end
        end
      end
    end

    request.reload
    assert request.queued?
    assert_equal "Spanish", request.clip_language
    assert_equal detected_data, request.create_song_progress.data
    assert request.course.pending?
    assert_equal User::SIGNUP_CREDITS, @user.reload.credit_balance,
                 "nothing is charged until the course reaches their channel"
  end

  test "defaults an English translation to Hebrew when English is detected" do
    request = create_provisional_request

    assert_enqueued_with(job: CreateCourseJob) do
      CreateSongProgress.stub(:detect_language, [ @english, {} ]) do
        Youtube::Oembed.stub(:fetch, @video) do
          DetectImportLanguageJob.perform_now(request.id)
        end
      end
    end

    request.reload
    assert request.queued?
    assert_equal "English", request.clip_language
    assert_equal "Hebrew", request.translation_language
    assert request.course.course_translations.exists?(language: @hebrew)
    assert_equal User::SIGNUP_CREDITS, @user.reload.credit_balance
  end

  test "a duplicate detected during an existing import does not later report a false timeout" do
    first = create_provisional_request

    CreateSongProgress.stub(:detect_language, [ @spanish, {} ]) do
      Youtube::Oembed.stub(:fetch, @video) do
        DetectImportLanguageJob.perform_now(first.id)
        first.reload
        assert first.queued?

        # The first request now has a source language, so a second automatic
        # import can create a new detecting row before the course is published.
        duplicate = Imports::Create.call(
          user: @user, url: CANONICAL, translation_language: "English",
          client_token: "duplicate-detection"
        ).import_request
        assert_not_equal first.id, duplicate.id
        assert duplicate.detecting?

        assert_no_enqueued_jobs only: [ CreateCourseJob, ActionMailer::MailDeliveryJob ] do
          DetectImportLanguageJob.perform_now(duplicate.id)
        end
        assert duplicate.reload.canceled?
        assert_equal first, duplicate.duplicate_of
        assert_equal first.course, duplicate.course
        assert_equal "duplicate-detection", duplicate.client_token
        assert_nil duplicate.failure_reason

        replay = Imports::Create.call(
          user: @user, url: CANONICAL, translation_language: "English",
          client_token: duplicate.client_token
        )
        assert_equal first, replay.import_request

        # Stand in for the pipeline finishing the original course; delivery and
        # the duplicate's timeout still use the real production handlers.
        first.course.published!
        Imports::Settlement.complete!(first)
        assert first.reload.ready?
        balance_after_delivery = @user.reload.credit_balance

        travel_to duplicate.created_at + ImportRequest::TIMEOUT + 1.second do
          assert_no_enqueued_jobs do
            ImportRequestTimeoutJob.perform_now(duplicate.id)
          end
        end

        duplicate.reload
        assert_not duplicate.failed?,
          "the same video was delivered by request #{first.id}, but the duplicate failed: #{duplicate.failure_reason}"
        assert_not duplicate.active?, "the duplicate should be resolved once the video is delivered"
        assert_equal balance_after_delivery, @user.reload.credit_balance,
          "the duplicate must not charge for the same course again"
      end
    end
  end

  test "joins existing Spanish progress without discarding the detected Scribe transcript" do
    request = create_provisional_request
    provisional = request.create_song_progress
    canonical = CreateSongProgress.create!(
      youtubeurl: CANONICAL,
      clip_language: "Spanish",
      data: { "stt_candidates" => { "supadata" => { "text" => "hola" } } }
    )
    detected_data = {
      "stt_candidates" => {
        "elevenlabs" => { "text" => "hola", "words" => [ { "text" => "hola", "start" => 0, "end" => 0.5 } ] }
      }
    }

    assert_enqueued_with(job: CreateCourseJob) do
      CreateSongProgress.stub(:detect_language, [ @spanish, detected_data ]) do
        Youtube::Oembed.stub(:fetch, @video) do
          DetectImportLanguageJob.perform_now(request.id)
        end
      end
    end

    assert_equal canonical, request.reload.create_song_progress
    assert_nil CreateSongProgress.find_by(id: provisional.id)
    assert_equal "hola", canonical.reload.data.dig("stt_candidates", "supadata", "text")
    assert_equal detected_data.dig("stt_candidates", "elevenlabs"),
                 canonical.data.dig("stt_candidates", "elevenlabs")
  end

  test "a guest claim reuses detection and joins the admin-owned course" do
    source = Youtube::Oembed.stub(:fetch, @video) do
      Imports::Create.call(
        user: @user,
        url: CANONICAL,
        translation_language: "English",
        guest_started: true
      ).import_request
    end
    learner = User.create!(email: "guest-claim@example.com", password: "password123", confirmed_at: Time.zone.now)
    claim = GuestImports::Claim.call(user: learner, source_import_request: source)
    detected_data = { "lyric_lines" => [ "hola" ], "stt_words" => [ { "text" => "hola" } ] }

    assert_no_enqueued_jobs only: DetectImportLanguageJob do
      CreateSongProgress.stub(:detect_language, [ @spanish, detected_data ]) do
        Youtube::Oembed.stub(:fetch, @video) do
          DetectImportLanguageJob.perform_now(source.id)
        end
      end
    end

    source.reload
    claim.reload
    assert source.queued?
    assert claim.importing?
    assert_equal source.course, claim.course
    assert_equal @user, source.course.user
    assert_equal source.create_song_progress, claim.create_song_progress
  end

  private

  def create_provisional_request
    Youtube::Oembed.stub(:fetch, @video) do
      Imports::Create.call(user: @user, url: CANONICAL, translation_language: "English").import_request
    end
  end
end
