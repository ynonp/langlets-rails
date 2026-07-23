require "test_helper"
require "minitest/mock"

# The finalizer is the "is it done yet?" half of the import flow: the pipeline
# streams patches and stops, so completion is re-derived from the blob after
# every callback rather than signalled once.
class Imports::FinalizerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  VIDEO_ID = "finalizeVid".freeze
  CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  setup do
    @user    = User.create!(email: "finalizer@example.com", password: "password123", confirmed_at: Time.zone.now)
    @spanish = languages(:spanish)
    @english = languages(:english)

    @progress = CreateSongProgress.create!(
      youtubeurl: CANONICAL, clip_language: "Spanish", translation_language: "English", data: {}
    )
    @course = Course.create!(
      name: "Despacito", slug: "despacito-#{VIDEO_ID.downcase}", main_media_url: CANONICAL,
      youtube_video_id: VIDEO_ID, language: @spanish, user: @user, status: :processing
    )
    @course.course_translations.create!(language: @english, name: @course.name, status: :pending)
    @request = create_request(user: @user, charged: true)
    Credits::Ledger.spend!(user: @user, subject: @request, idempotency_key: "import:#{@request.id}")
  end

  test "an incomplete record leaves the import alone" do
    @progress.update!(data: complete_data.except("lesson_ratings"))

    finalize

    assert @request.reload.importing?, "still waiting on the pipeline"
    assert_not @course.reload.published?
  end

  # Complete for Hebrew is not complete for English: the per-language half of
  # the check is what stops a rider being marked ready off someone else's work.
  test "a record complete in another language does not finish this import" do
    data = complete_data
    data["translations"] = { "he" => data["translations"]["en"] }
    @progress.update!(data: data)

    finalize

    assert @request.reload.importing?
  end

  test "a complete record publishes the course and marks the import ready" do
    @progress.update!(data: complete_data)

    finalize

    @request.reload
    assert @request.ready?
    assert_equal 100, @request.progress_percent
    assert @course.reload.published?

    enrollment = @user.enrollments.sole
    assert_equal @course, enrollment.course
    assert enrollment.imported?, "they paid for it, so it's an import not a library add"
  end

  test "every rider on a shared import is enrolled when it publishes" do
    rider = User.create!(email: "rider@example.com", password: "password123", confirmed_at: Time.zone.now)
    create_request(user: rider, charged: false)
    @progress.update!(data: complete_data)

    finalize

    assert_equal @course, rider.enrollments.sole.course
    assert rider.enrollments.sole.library?, "they didn't pay, so it reads as a library add"
  end

  # Every callback asks again, so this runs many times against a finished
  # record. It must not rebuild the course or re-enroll anyone.
  test "running again over a finished import changes nothing" do
    @progress.update!(data: complete_data)
    finalize

    builds = 0
    finalize(on_build: -> { builds += 1 })

    assert_equal 0, builds, "the course was already built"
    assert_equal 1, @user.enrollments.count
    assert @request.reload.ready?
  end

  # A rider can join asking for a language the run was never started for, and
  # the pipeline fills one language per run.
  test "a language nobody ran gets its own run once the course exists" do
    rider = User.create!(email: "hebrew@example.com", password: "password123", confirmed_at: Time.zone.now)
    rider.import_requests.create!(
      youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
      clip_language: "Spanish", translation_language: "Hebrew",
      course: @course, create_song_progress: @progress, status: :importing
    )
    @progress.update!(data: complete_data)

    assert_enqueued_with(job: AddCourseTranslationJob,
                         args: [ @progress.id, @course.id, languages(:hebrew).id ]) do
      finalize
    end

    assert @request.reload.ready?, "English was ready and should not wait for Hebrew"
  end

  # Triggering is hooked to the publish transition, which happens once. A
  # language whose run fails must wait out its deadline, not make every later
  # callback start another run.
  test "a language is not retriggered on every later callback" do
    rider = User.create!(email: "french@example.com", password: "password123", confirmed_at: Time.zone.now)
    rider.import_requests.create!(
      youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
      clip_language: "Spanish", translation_language: "French",
      course: @course, create_song_progress: @progress, status: :importing
    )
    @progress.update!(data: complete_data)
    finalize

    assert_no_enqueued_jobs(only: AddCourseTranslationJob) { finalize }
  end

  # Every exhausted pipeline action reports through the callback, so waiting
  # out the full timeout would tell the user nothing new.
  test "a blocking pipeline error fails the import immediately" do
    @progress.update!(data: {
      "errors" => [ { "step" => "extract_lyrics", "error_message" => "video is private",
                      "occurred_at" => Time.zone.now.iso8601 } ]
    })

    finalize

    @request.reload
    assert @request.failed?
    assert @request.refunded?
    assert_equal "video is private", @request.failure_reason
    assert_equal 3, @user.reload.credit_balance
    assert @course.reload.error?
  end

  test "a downstream pipeline error fails the import immediately" do
    @progress.update!(data: {
      "phrases" => [ { "text_l1" => "hola", "words" => [ { "text" => "hola" } ] } ],
      "errors" => [ { "step" => "add_lessons", "error_message" => "model returned no lessons",
                      "occurred_at" => Time.zone.now.iso8601 } ]
    })

    finalize

    assert @request.reload.failed?
    assert_equal "model returned no lessons", @request.failure_reason
    assert_equal 3, @user.reload.credit_balance
  end

  # A resumed run skips the steps it already finished, so it never gets the
  # chance to clear their entries. An error older than the request is somebody
  # else's, and killing a paid import over it would be a bug.
  test "a stale blocking error from an earlier run is ignored" do
    @progress.update!(data: {
      "errors" => [ { "step" => "extract_lyrics", "error_message" => "old failure",
                      "occurred_at" => 1.hour.ago.iso8601 } ]
    })

    finalize

    assert @request.reload.importing?, "an error that predates the request belongs to an earlier run"
    assert_equal 2, @user.reload.credit_balance, "nothing was refunded"
  end

  # Phrases on record mean transcription landed, whatever an older entry says.
  test "an error contradicted by the data on record is ignored" do
    @progress.update!(data: complete_data.merge(
      "errors" => [ { "step" => "force_alignment", "error_message" => "timing failed",
                      "occurred_at" => Time.zone.now.iso8601 } ]
    ))

    finalize

    assert @request.reload.ready?
  end

  test "a build that blows up refunds the import rather than leaving it spinning" do
    @progress.update!(data: complete_data)

    finalize(on_build: -> { raise "translation data is missing" })

    @request.reload
    assert @request.failed?
    assert @request.refunded?
    assert_equal "translation data is missing", @request.failure_reason
    assert @course.reload.error?
  end

  private

  def create_request(user:, charged:)
    user.import_requests.create!(
      youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
      clip_language: "Spanish", translation_language: "English",
      course: @course, create_song_progress: @progress,
      status: :importing, charged: charged
    )
  end

  # Enough of a blob for complete_for?(English): all six neutral steps done and
  # the English payload finalized by the pipeline's finalize_translation step.
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

  # BuildSong has its own tests; here it only needs to stand in for "the course
  # got built", so lessons are faked with a counter the assertions can read.
  def finalize(on_build: nil)
    builder = Object.new
    builder.define_singleton_method(:call) { on_build&.call }
    builder.define_singleton_method(:add_translation) { |_language| on_build&.call }

    mail = Object.new
    def mail.deliver_now = true

    CourseBuilder::BuildSong.stub(:new, ->(*) { builder }) do
      CourseMailer.stub(:creation_complete, ->(*) { mail }) do
        CourseMailer.stub(:creation_failed, ->(*) { mail }) do
          Imports::Finalizer.call(@progress)
        end
      end
    end
  end
end
