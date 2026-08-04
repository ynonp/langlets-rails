require "test_helper"

# ImportRequest#retry! — the operator's way back from a failed import.
#
# Every test here is really asking the same question: does the retry leave the
# system in a state where the pipeline can actually finish? A row that says
# `queued` while the course is still `error`, or while a stale pipeline failure
# sits in the shared record, looks retried and isn't.
class ImportRequestTest < ActiveJob::TestCase
  VIDEO_ID = "retryVid001".freeze
  CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  setup do
    @user    = User.create!(email: "retry@example.com", password: "password123", confirmed_at: Time.zone.now)
    @spanish = languages(:spanish)
    @english = languages(:english)

    @progress = CreateSongProgress.create!(
      youtubeurl: CANONICAL, clip_language: "Spanish", data: {}
    )
    @course = Course.create!(
      name: "Despacito", slug: "despacito-#{VIDEO_ID.downcase}", main_media_url: CANONICAL,
      youtube_video_id: VIDEO_ID, language: @spanish, user: @user, status: :error
    )
    @course.course_translations.create!(language: @english, name: @course.name, status: :error)

    @request = @user.import_requests.create!(
      youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
      clip_language: "Spanish", translation_language: "English",
      course: @course, create_song_progress: @progress,
      status: :failed, failure_reason: "translate: quota exceeded",
      progress_percent: 40, pipeline_step: "Translating · step 3 of 6",
    )
  end

  test "a failed request goes back to queued with its failure state cleared" do
    @request.retry!

    @request.reload
    assert @request.queued?
    assert_nil @request.failure_reason
    assert_nil @request.pipeline_step
    assert_equal 0, @request.progress_percent
  end

  test "the course is reset to pending so CreateCourseJob can claim it" do
    assert_enqueued_with(job: CreateCourseJob, args: [ @progress.id, @course.id, @english.id ]) do
      @request.retry!
    end

    assert @course.reload.pending?, "Course#process only claims a pending course"
  end

  test "a fresh deadline is scheduled" do
    assert_enqueued_with(job: ImportRequestTimeoutJob, args: [ @request.id ], at: ->(at) { at > 9.minutes.from_now }) do
      @request.retry!
    end
  end

  # The one that bites: the pipeline's own error entry survives a resumed run
  # unless the step it belongs to happens to re-run, so the finalizer would fail
  # the request again before the retry got anywhere.
  test "the previous run's error no longer blocks the retried request" do
    @progress.update!(data: { "errors" => [ { "step" => "translate", "error_message" => "quota exceeded", "occurred_at" => 5.minutes.ago.iso8601 } ] })

    @request.retry!

    Imports::Finalizer.call(@progress.reload)

    assert @request.reload.queued?, "a failure from the previous run must not settle the retry"
    refute @course.reload.error?
  end

  # A failure the retried run reports must still count.
  test "an error from the new run does block it" do
    @request.retry!

    @progress.update!(data: { "errors" => [ { "step" => "translate", "error_message" => "quota exceeded", "occurred_at" => 1.second.from_now.iso8601 } ] })
    Imports::Finalizer.call(@progress.reload)

    assert @request.reload.failed?
    assert_match(/quota exceeded/, @request.failure_reason)
  end

  # Restarting a failed import is not a sale. It is not a refund either — the
  # failure took nothing, because the credit only moves when the course reaches
  # the user's channel.
  test "credits are left alone by a retry" do
    balance = @user.reload.credit_balance
    entries = CreditLedgerEntry.where(user: @user).count

    @request.retry!

    assert_equal balance, @user.reload.credit_balance
    assert_equal entries, CreditLedgerEntry.where(user: @user).count
  end

  test "a published course keeps its status and only re-runs the failed language" do
    @course.update!(status: :published)

    assert_enqueued_with(job: AddCourseTranslationJob, args: [ @progress.id, @course.id, @english.id ]) do
      @request.retry!
    end

    assert @course.reload.published?, "a live course must not be unpublished by one language's retry"
    assert @course.course_translations.find_by(language: @english).pending?
  end

  test "it rides along on a run already in flight instead of starting a second one" do
    other = User.create!(email: "rider@example.com", password: "password123", confirmed_at: Time.zone.now)
    other.import_requests.create!(
      youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
      clip_language: "Spanish", translation_language: "English",
      course: @course, create_song_progress: @progress, status: :importing
    )

    assert_no_enqueued_jobs(only: [ CreateCourseJob, AddCourseTranslationJob ]) do
      @request.retry!
    end

    assert @request.reload.queued?, "it still has to be active for the finalizer to settle it"
  end

  test "only a failed request can be retried" do
    @request.update!(status: :importing)

    error = assert_raises(ImportRequest::NotRetryable) { @request.retry! }
    assert_match(/only a failed import/, error.message)
  end

  test "it refuses when the same user already has this video importing" do
    @user.import_requests.create!(
      youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
      clip_language: "Spanish", translation_language: "English",
      course: @course, create_song_progress: @progress, status: :queued
    )

    assert_raises(ImportRequest::NotRetryable) { @request.retry! }
    assert @request.reload.failed?, "the dedupe index would have rejected this anyway"
  end

  test "it refuses a request with nothing to resume" do
    @request.update!(course: nil)

    assert_raises(ImportRequest::NotRetryable) { @request.retry! }
  end

  test "clip and translation languages must differ" do
    @request.translation_language = @request.clip_language

    refute @request.valid?
    assert_includes @request.errors[:translation_language], "must differ from clip language"
  end

  test "destroy_with_artifacts deletes the exclusive import graph" do
    @course.update!(create_song_progress: @progress)
    medium = Medium.create!(url: CANONICAL, language: @spanish)
    lesson = Lesson.create!(course: @course, medium: medium, user: @user, name: "Imported lesson")
    phrase = Phrase.create!(medium: medium, l1: @spanish, text_l1: "Hola")

    @request.destroy_with_artifacts!

    refute ImportRequest.exists?(@request.id)
    refute Course.exists?(@course.id)
    refute CreateSongProgress.exists?(@progress.id)
    refute Medium.exists?(medium.id)
    refute Lesson.exists?(lesson.id)
    refute Phrase.exists?(phrase.id)
  end

  test "destroy_with_artifacts rejects an active import without deleting anything" do
    @request.update!(status: :importing)

    error = assert_raises(ImportRequest::ArtifactsNotDestroyable) do
      @request.destroy_with_artifacts!
    end

    assert_match(/still active/, error.message)
    assert ImportRequest.exists?(@request.id)
    assert Course.exists?(@course.id)
    assert CreateSongProgress.exists?(@progress.id)
  end

  test "destroy_with_artifacts rejects shared artifacts without deleting anything" do
    @course.update!(create_song_progress: @progress)
    other = User.create!(email: "shared@example.com", password: "password123", confirmed_at: Time.zone.now)
    sibling = other.import_requests.create!(
      youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
      clip_language: "Spanish", translation_language: "English",
      course: @course, create_song_progress: @progress, status: :ready
    )

    error = assert_raises(ImportRequest::ArtifactsNotDestroyable) do
      @request.destroy_with_artifacts!
    end

    assert_match(/shared by another ImportRequest/, error.message)
    assert ImportRequest.exists?(@request.id)
    assert ImportRequest.exists?(sibling.id)
    assert Course.exists?(@course.id)
    assert CreateSongProgress.exists?(@progress.id)
  end
end
