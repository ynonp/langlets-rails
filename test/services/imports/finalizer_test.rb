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
      youtubeurl: CANONICAL, clip_language: "Spanish", data: {}
    )
    @course = Course.create!(
      name: "Despacito", slug: "despacito-#{VIDEO_ID.downcase}", main_media_url: CANONICAL,
      youtube_video_id: VIDEO_ID, language: @spanish, user: @user, status: :processing
    )
    @course.course_translations.create!(language: @english, name: @course.name, status: :pending)
    @request = create_request(user: @user)
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
    assert enrollment.imported?, "they asked for this course, so it's an import not a library add"
    assert_equal 2, @user.reload.credit_balance, "publishing into their channel is where it is paid for"
  end

  # Riding along shares the pipeline run, not the purchase: the rider's own copy
  # is published into their own channel and charged to them there.
  test "every rider on a shared import is enrolled and charged when it publishes" do
    rider = User.create!(email: "rider@example.com", password: "password123", confirmed_at: Time.zone.now)
    create_request(user: rider)
    @progress.update!(data: complete_data)

    finalize

    assert_equal @course, rider.enrollments.sole.course
    assert rider.enrollments.sole.imported?, "they asked for it themselves"
    assert_equal 2, rider.reload.credit_balance
    assert rider.default_channel.channel_items.exists?(course: @course)
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
    assert_equal "video is private", @request.failure_reason
    assert_equal 3, @user.reload.credit_balance, "nothing published, so nothing paid"
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
    assert_equal 3, @user.reload.credit_balance, "still unpublished, so still unpaid"
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

  test "a build that blows up fails the import rather than leaving it spinning" do
    @progress.update!(data: complete_data)

    finalize(on_build: -> { raise "translation data is missing" })

    @request.reload
    assert @request.failed?
    assert_equal "translation data is missing", @request.failure_reason
    assert_equal 3, @user.reload.credit_balance, "a course that never published was never charged for"
    assert @course.reload.error?
  end

  # The residual race the up-front guard cannot close: the balance ran out
  # between asking and delivery. Failing is right — the alternative is handing
  # over a course nobody paid for.
  test "an import whose user can no longer pay fails instead of publishing free" do
    User.where(id: @user.id).update_all(credit_balance: 0)
    @progress.update!(data: complete_data)

    finalize

    assert @request.reload.failed?
    assert_not @user.default_channel.channel_items.exists?(course: @course)
  end

  # failure_reason is read by people — the Queue renders it and the share
  # extension pulls it out of the API — so it must never be Credits::Ledger's
  # internal message, which names a user id.
  test "running out of credits is reported in words the user can act on" do
    User.where(id: @user.id).update_all(credit_balance: 0)
    @progress.update!(data: complete_data)

    finalize

    assert_equal ImportRequest::INSUFFICIENT_CREDITS, @request.reload.failure_reason
    assert @request.insufficient_credits?
    assert_no_match(/user \d+/, @request.failure_reason)
  end

  # The course is shared. One person's empty balance must not knock it back to
  # `error` underneath everyone else who is riding the same run.
  test "one user's empty balance does not damage the shared course" do
    rider = User.create!(email: "solvent@example.com", password: "password123", confirmed_at: Time.zone.now)
    create_request(user: rider)
    User.where(id: @user.id).update_all(credit_balance: 0)
    @progress.update!(data: complete_data)

    finalize

    assert @course.reload.published?, "still live for everyone who can pay for it"
    assert rider.reload.enrollments.exists?(course: @course)
    assert_equal 2, rider.credit_balance
    assert @request.reload.failed?
  end

  private

  def create_request(user:)
    user.import_requests.create!(
      youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
      clip_language: "Spanish", translation_language: "English",
      course: @course, create_song_progress: @progress,
      status: :importing
    )
  end

  # Enough of a blob for complete_for?(English): all seven neutral steps done and
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
    builder.define_singleton_method(:call) { |_language| on_build&.call }
    builder.define_singleton_method(:add_translation) { |_language| on_build&.call }

    # Notifications are recorded here and delivered in a job, so nothing is
    # mailed inline and there is no mailer left to stub out.
    CourseBuilder::BuildSong.stub(:new, ->(*) { builder }) do
      Imports::Finalizer.call(@progress)
    end
  end
end
