require "test_helper"
require "minitest/mock"

# The backstop. Nothing in the import path blocks any more, so this fixed
# wall-clock deadline is the only thing standing between a silently dead
# pipeline run and a Queue card that spins forever.
class ImportRequestTimeoutJobTest < ActiveJob::TestCase
  VIDEO_ID = "timeoutVid1".freeze
  CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  setup do
    @user    = User.create!(email: "timeout@example.com", password: "password123", confirmed_at: Time.zone.now)
    @spanish = languages(:spanish)
    @english = languages(:english)

    @progress = CreateSongProgress.create!(
      youtubeurl: CANONICAL, clip_language: "Spanish", data: {}
    )
    @course = Course.create!(
      name: "Despacito", slug: "despacito-#{VIDEO_ID.downcase}", main_media_url: CANONICAL,
      youtube_video_id: VIDEO_ID, language: @spanish, user: @user, status: :processing
    )
    @course.course_translations.create!(language: @english, name: @course.name, status: :pending)
    @request = @user.import_requests.create!(
      youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
      clip_language: "Spanish", translation_language: "English",
      course: @course, create_song_progress: @progress,
      status: :importing
    )
  end

  test "the deadline is scheduled for every request the moment it is created" do
    other = User.create!(email: "scheduled@example.com", password: "password123", confirmed_at: Time.zone.now)

    assert_enqueued_with(job: ImportRequestTimeoutJob, at: ->(at) { at > 9.minutes.from_now }) do
      other.import_requests.create!(
        youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
        clip_language: "Spanish", translation_language: "English",
        course: @course, create_song_progress: @progress, status: :queued
      )
    end
  end

  test "an import still running when the deadline passes is failed, and costs nothing" do
    run_job

    @request.reload
    assert @request.failed?
    assert_match(/timed out/, @request.failure_reason)
    assert_equal 3, @user.reload.credit_balance, "an import that never published was never paid for"
    assert @course.reload.error?
  end

  # The pipeline keeps reporting its failures through the callback even though
  # nothing blocks on them now, so say what actually went wrong.
  #
  # The reason is the pipeline's `error_message` alone. This job's own
  # "<step>: <message>" format does not apply here: the last-chance
  # `Imports::Finalizer.call` at the top of #perform sees the same blocking
  # error first, fails the request with its own wording, and #perform then
  # returns on the `active?` check without reaching #reason. That leaves #reason
  # for the narrow case the finalizer declines to act on — `pipeline_complete?`
  # true while the requested language is still unfinished.
  test "a failure the pipeline reported is used as the reason" do
    @progress.update!(data: {
      "errors" => [ { "step" => "translate", "error_message" => "model refused the prompt" } ]
    })

    run_job

    assert_equal "model refused the prompt", @request.reload.failure_reason
  end

  test "an import that already finished is left alone" do
    @request.update!(status: :ready, progress_percent: 100)

    run_job

    assert @request.reload.ready?
    assert_equal 3, @user.reload.credit_balance, "already settled; this job touches nothing"
  end

  # The last patch and the finalizer that acts on it are not atomic, so an
  # import whose data landed a moment ago must not be failed on a technicality.
  test "data that arrived at the last moment finishes the import instead" do
    @progress.update!(data: complete_data)

    run_job

    assert @request.reload.ready?
    assert @course.reload.published?
    assert_equal 2, @user.reload.credit_balance, "delivered at the last moment, and paid for then"
  end

  test "a deleted import request is not an error" do
    assert_nothing_raised { ImportRequestTimeoutJob.perform_now(-1) }
  end

  # A course already live in another language must not be knocked back to
  # `error` because one translation ran out of time.
  test "a published course survives one of its translations timing out" do
    @course.update!(status: :published)

    run_job

    assert @request.reload.failed?
    assert @course.reload.published?
  end

  private

  def complete_data
    {
      "phrases" => [ { "text_l1" => "hola", "timestamp" => "00:00.00", "words" => [ { "word" => "hola" } ] } ],
      "lessons" => "# Lesson\n00:00.00\n00:01.00",
      "lesson_ratings" => [ 5 ],
      "similar_sounds" => "hola: ola",
      "translations" => {
        "en" => {
          "lessons" => "# Lesson\n00:00.00\n00:01.00",
          "phrases" => [ { "text" => "hello", "words" => [ "hello" ] } ]
        }
      }
    }
  end

  def run_job
    builder = Object.new
    def builder.call(_language) = true
    def builder.add_translation(_language) = true

    CourseBuilder::BuildSong.stub(:new, ->(*) { builder }) do
      ImportRequestTimeoutJob.perform_now(@request.id)
    end
  end
end
