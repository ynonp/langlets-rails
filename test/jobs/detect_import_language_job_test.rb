require "test_helper"

class DetectImportLanguageJobTest < ActiveJob::TestCase
  VIDEO_ID = "kJQP7kiw5Fk".freeze
  CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  setup do
    @user = User.create!(email: "detect-job@example.com", password: "password123", confirmed_at: Time.zone.now)
    @spanish = languages(:spanish)
    @english = languages(:english)
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
      CreateSongPipelineHttp.stub(:detect_language, [ @spanish, detected_data ]) do
        Youtube::Oembed.stub(:fetch, @video) do
          DetectImportLanguageJob.perform_now(request.id)
        end
      end
    end

    request.reload
    assert request.queued?
    assert_equal "Spanish", request.clip_language
    assert_equal detected_data, request.create_song_progress.data
    assert request.course.pending?
    assert_equal 3, @user.reload.credit_balance,
                 "nothing is charged until the course reaches their channel"
  end

  test "fails when the detected and translation languages match" do
    request = create_provisional_request

    assert_raises(Imports::UnsupportedLanguage) do
      CreateSongPipelineHttp.stub(:detect_language, [ @english, {} ]) do
        Youtube::Oembed.stub(:fetch, @video) do
          DetectImportLanguageJob.perform_now(request.id)
        end
      end
    end

    assert request.reload.failed?
    assert_equal 3, @user.reload.credit_balance
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
      CreateSongPipelineHttp.stub(:detect_language, [ @spanish, detected_data ]) do
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
    assert_equal "es", learner.reload.ios_lang
  end

  private

  def create_provisional_request
    Youtube::Oembed.stub(:fetch, @video) do
      Imports::Create.call(user: @user, url: CANONICAL, translation_language: "English").import_request
    end
  end
end
