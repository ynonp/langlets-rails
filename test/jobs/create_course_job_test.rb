require "test_helper"
require "minitest/mock"

class CreateCourseJobTest < ActiveJob::TestCase
  VIDEO_ID = "kJQP7kiw5Fk".freeze
  CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  setup do
    @user    = User.create!(email: "job@example.com", password: "password123", confirmed_at: Time.zone.now)
    @spanish = languages(:spanish)
    @english = languages(:english)

    @progress = CreateSongProgress.create!(
      youtubeurl: CANONICAL, clip_language: "Spanish", translation_language: "English", data: {}
    )
    @course = Course.create!(
      name: "Despacito", slug: "despacito-#{VIDEO_ID.downcase}", main_media_url: CANONICAL,
      youtube_video_id: VIDEO_ID, language: @spanish, translation_language: @english,
      user: @user, status: :pending
    )
    @request = create_request(user: @user, charged: true, status: :queued)
    Credits::Ledger.spend!(user: @user, subject: @request, idempotency_key: "import:#{@request.id}")
  end

  test "publishing marks the request ready and puts the course on Home" do
    run_job

    @request.reload
    assert @request.ready?
    assert_equal 100, @request.progress_percent
    assert @course.reload.published?

    enrollment = @user.enrollments.sole
    assert_equal @course, enrollment.course
    assert enrollment.imported?, "they paid for it, so it's an import not a library add"
  end

  test "a failed import refunds the credit and records why" do
    assert_equal 2, @user.reload.credit_balance

    assert_raises(RuntimeError) { run_job(raising: "transcription exploded") }

    @request.reload
    assert @request.failed?
    assert @request.refunded?
    assert_equal "transcription exploded", @request.failure_reason
    assert_equal 3, @user.reload.credit_balance, "the credit must come back"
    assert @course.reload.error?
  end

  test "the refund is recorded in the ledger and the balance still agrees" do
    assert_raises(RuntimeError) { run_job(raising: "boom") }

    assert_equal 1, @user.credit_ledger_entries.import_refund.count
    assert_equal @user.reload.credit_balance, @user.credit_ledger_entries.sum(:amount)
  end

  # good_job's retry_on_unhandled_error is false, so the job's rescue is the final
  # word — but a manual re-run must not mint credits.
  test "failing twice refunds only once" do
    assert_raises(RuntimeError) { run_job(raising: "boom") }

    # reload first: the job called error! on its own instance, so this one still
    # reads `pending` and update! would issue no SQL at all.
    @request.reload.update!(status: :importing)
    @course.reload.update!(status: :pending)

    assert_raises(RuntimeError) { run_job(raising: "boom again") }

    assert_equal 1, @user.credit_ledger_entries.import_refund.count
    assert_equal 3, @user.reload.credit_balance
  end

  # Users who joined someone else's in-flight import never paid.
  test "a rider on a shared import is failed but not refunded" do
    rider = User.create!(email: "rider@example.com", password: "password123", confirmed_at: Time.zone.now)
    rider_request = create_request(user: rider, charged: false, status: :importing)

    assert_raises(RuntimeError) { run_job(raising: "boom") }

    rider_request.reload
    assert rider_request.failed?
    assert_not rider_request.refunded?
    assert_equal 3, rider.reload.credit_balance, "never charged, so nothing to give back"
    assert_equal 0, rider.credit_ledger_entries.import_refund.count
  end

  test "every rider on a shared import is enrolled when it publishes" do
    rider = User.create!(email: "rider2@example.com", password: "password123", confirmed_at: Time.zone.now)
    create_request(user: rider, charged: false, status: :importing)

    run_job

    assert_equal @course, rider.enrollments.sole.course
    assert rider.enrollments.sole.library?, "they didn't pay, so it reads as a library add"
    assert_equal @course, @user.enrollments.sole.course
  end

  test "the request is marked importing while the pipeline runs" do
    observed = nil
    run_job(during: -> { observed = @request.reload.status })

    assert_equal "importing", observed
  end

  test "a course already claimed by another job is left alone" do
    @course.update!(status: :processing)

    run_job

    assert @request.reload.queued?, "an unclaimed course must not be touched"
    assert @course.reload.processing?
  end

  private

  def create_request(user:, charged:, status:)
    user.import_requests.create!(
      youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
      clip_language: "Spanish", translation_language: "English",
      course: @course, create_song_progress: @progress,
      status: status, charged: charged
    )
  end

  # Replaces the job's two slow parts — the LLM pipeline and the course builder —
  # leaving its bookkeeping (charge, refund, enroll, status) under test.
  def run_job(during: nil, raising: nil)
    progress = @progress
    progress.define_singleton_method(:create_data) do
      raise RuntimeError, raising if raising

      during&.call
      nil
    end

    builder = Object.new
    def builder.call = true

    mail = Object.new
    def mail.deliver_now = true

    # Note the lambdas: Minitest's stub *calls* any value that responds to :call,
    # so returning the builder directly would invoke it instead.
    CreateSongProgress.stub(:find, progress) do
      CourseBuilder::BuildSong.stub(:new, ->(*) { builder }) do
        CourseMailer.stub(:creation_complete, ->(*) { mail }) do
          CourseMailer.stub(:creation_failed, ->(*) { mail }) do
            CreateCourseJob.perform_now(@progress.id, @course.id)
          end
        end
      end
    end
  end
end
