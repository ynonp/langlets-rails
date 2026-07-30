require "test_helper"
require "minitest/mock"

# CreateCourseJob is a trigger now: it claims the course, marks the requests
# importing, starts the run and leaves. Publishing is Imports::Finalizer's job
# (see imports/finalizer_test.rb) and giving up is ImportRequestTimeoutJob's.
class CreateCourseJobTest < ActiveJob::TestCase
  VIDEO_ID = "kJQP7kiw5Fk".freeze
  CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  setup do
    # The AI steps run out of process now, so the job expects this configured.
    @previous_pipeline_url = ENV["PIPELINE_URL"]
    ENV["PIPELINE_URL"] = "https://pipeline.test"

    @user    = User.create!(email: "job@example.com", password: "password123", confirmed_at: Time.zone.now)
    @spanish = languages(:spanish)
    @english = languages(:english)

    @progress = CreateSongProgress.create!(
      youtubeurl: CANONICAL, clip_language: "Spanish", translation_language: "English", data: {}
    )
    @course = create_translated_course!(
      name: "Despacito", slug: "despacito-#{VIDEO_ID.downcase}", main_media_url: CANONICAL,
      youtube_video_id: VIDEO_ID, language: @spanish, translation_language: @english,
      user: @user, status: :pending
    )
    @request = create_request(user: @user, charged: true, status: :queued)
    Credits::Ledger.spend!(user: @user, subject: @request, idempotency_key: "import:#{@request.id}")
  end

  teardown do
    ENV["PIPELINE_URL"] = @previous_pipeline_url
  end

  # The whole point of the refactor: the job hands the run off and returns, so a
  # worker thread is not held for the minutes a pipeline takes and the same
  # worker can start the next import immediately.
  test "the run is triggered and the job returns without waiting for it" do
    received = []

    run_job(trigger: ->(**kwargs) { received << kwargs })

    assert_equal 1, received.size, "one run covers the record's own language"
    assert_equal @progress, received.first[:progress]
    assert @request.reload.importing?, "the card shows as importing while the pipeline works"
    assert @course.reload.processing?, "publishing waits for the data, not for this job"
  end

  test "the request is marked importing before the run is triggered" do
    observed = nil
    run_job(trigger: ->(**) { observed = @request.reload.status })

    assert_equal "importing", observed
  end

  # Every request gets a wall-clock deadline the moment it is created, so
  # nothing can sit in the Queue forever no matter how the run dies.
  test "creating a request schedules its timeout" do
    other = User.create!(email: "deadline@example.com", password: "password123", confirmed_at: Time.zone.now)

    assert_enqueued_with(job: ImportRequestTimeoutJob) do
      create_request(user: other, charged: false, status: :queued)
    end
  end

  # A trigger that never got off the ground is the one failure this job still
  # owns — the run's own failures arrive through the callback instead.
  test "a trigger that fails refunds the credit and records why" do
    assert_equal 2, @user.reload.credit_balance

    assert_raises(CreateSongPipelineHttp::TriggerError) { run_job(raising: "pipeline unreachable") }

    @request.reload
    assert @request.failed?
    assert @request.refunded?
    assert_equal "pipeline unreachable", @request.failure_reason
    assert_equal 3, @user.reload.credit_balance, "the credit must come back"
    assert @course.reload.error?
  end

  test "the refund is recorded in the ledger and the balance still agrees" do
    assert_raises(CreateSongPipelineHttp::TriggerError) { run_job(raising: "boom") }

    assert_equal 1, @user.credit_ledger_entries.import_refund.count
    assert_equal @user.reload.credit_balance, @user.credit_ledger_entries.sum(:amount)
  end

  # Solid Queue leaves the failed execution failed, so the job's rescue is the
  # final word — but a manual re-run must not mint credits.
  test "failing twice refunds only once" do
    assert_raises(CreateSongPipelineHttp::TriggerError) { run_job(raising: "boom") }

    # reload first: the job called error! on its own instance, so this one still
    # reads `pending` and update! would issue no SQL at all.
    @request.reload.update!(status: :importing)
    @course.reload.update!(status: :pending)

    assert_raises(CreateSongPipelineHttp::TriggerError) { run_job(raising: "boom again") }

    assert_equal 1, @user.credit_ledger_entries.import_refund.count
    assert_equal 3, @user.reload.credit_balance
  end

  # Users who joined someone else's in-flight import never paid.
  test "a rider on a shared import is failed but not refunded" do
    rider = User.create!(email: "rider@example.com", password: "password123", confirmed_at: Time.zone.now)
    rider_request = create_request(user: rider, charged: false, status: :importing)

    assert_raises(CreateSongPipelineHttp::TriggerError) { run_job(raising: "boom") }

    rider_request.reload
    assert rider_request.failed?
    assert_not rider_request.refunded?
    assert_equal 3, rider.reload.credit_balance, "never charged, so nothing to give back"
    assert_equal 0, rider.credit_ledger_entries.import_refund.count
  end

  test "a course already claimed by another job is left alone" do
    @course.update!(status: :processing)
    triggered = false

    run_job(trigger: ->(**) { triggered = true })

    assert_not triggered, "the job that holds the claim has already started the run"
    assert @request.reload.queued?, "an unclaimed course must not be touched"
    assert @course.reload.processing?
  end

  # Re-importing a record the pipeline already filled in has nothing to wait
  # for, and no callback is ever coming to wake the finalizer up.
  test "a record that is already complete is finalized instead of retriggered" do
    @progress.update!(data: complete_data)
    triggered = false
    finalized = false

    Imports::Finalizer.stub(:call, ->(*) { finalized = true }) do
      run_job(trigger: ->(**) { triggered = true })
    end

    assert_not triggered, "there is nothing left for the pipeline to do"
    assert finalized
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

  # Enough of a blob for CreateSongProgress#complete_for?(English) to be true:
  # all six neutral steps done and the language payload finalized.
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

  # Replaces the job's one slow part — starting the run — leaving its
  # bookkeeping (claim, charge, refund, status) under test.
  def run_job(trigger: nil, raising: nil)
    stub = Object.new
    stub.define_singleton_method(:call) do
      raise CreateSongPipelineHttp::TriggerError, raising if raising

      true
    end

    mail = Object.new
    def mail.deliver_now = true

    # Note the lambdas: Minitest's stub *calls* any value that responds to :call,
    # so returning the stub directly would invoke it instead.
    CreateSongProgress.stub(:find, @progress) do
      CreateSongPipelineHttp.stub(:new, ->(**kwargs) { trigger&.call(**kwargs); stub }) do
        CourseMailer.stub(:creation_failed, ->(*) { mail }) do
          CreateCourseJob.perform_now(@progress.id, @course.id)
        end
      end
    end
  end
end
