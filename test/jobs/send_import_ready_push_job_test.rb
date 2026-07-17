require "test_helper"
require "minitest/mock"

class SendImportReadyPushJobTest < ActiveJob::TestCase
  VIDEO_ID = "kJQP7kiw5Fk".freeze
  CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  setup do
    @user = User.create!(email: "push@example.com", password: "password123", confirmed_at: Time.zone.now)
    @spanish = languages(:spanish)
    @english = languages(:english)
    @medium = Medium.create!(url: CANONICAL, language: @spanish, translation_language: @english)
    @course = Course.create!(name: "Despacito", slug: "despacito-push", main_media_url: CANONICAL,
                             youtube_video_id: VIDEO_ID, language: @spanish, translation_language: @english,
                             user: @user, status: :published)
    2.times { |i| Lesson.create!(course: @course, medium: @medium, user: @user, slug: "l#{i}", name: "L#{i}", order: i) }

    @request = @user.import_requests.create!(
      youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
      clip_language: "Spanish", translation_language: "English",
      title: "Despacito", status: :ready, course: @course, charged: true
    )
    @device = DeviceToken.register!(user: @user, token: "a" * 64)
  end

  test "pushes to the user's device and stamps notified_at" do
    sent = []
    stub_push(->(device, payload) { sent << [ device, payload ]; ok }) do
      SendImportReadyPushJob.perform_now(@request.id)
    end

    assert_equal 1, sent.size
    assert_equal @device, sent.first.first
    assert_not_nil @request.reload.notified_at
  end

  test "the payload says what the mockup says" do
    captured = nil
    stub_push(->(_device, payload) { captured = payload; ok }) do
      SendImportReadyPushJob.perform_now(@request.id)
    end

    assert_equal "Your course is ready!", captured[:alert][:title]
    assert_equal "“Despacito” is now 2 lessons. Tap to start practicing.", captured[:alert][:body]
    assert_equal "despacito-push", captured[:custom_payload][:course_slug]
  end

  # A re-run must not ping the user twice.
  test "does not push twice" do
    count = 0
    stub_push(->(_d, _p) { count += 1; ok }) do
      SendImportReadyPushJob.perform_now(@request.id)
      SendImportReadyPushJob.perform_now(@request.id)
    end

    assert_equal 1, count
  end

  test "does not push for an import that isn't ready" do
    @request.update!(status: :importing, notified_at: nil)
    count = 0

    stub_push(->(_d, _p) { count += 1; ok }) { SendImportReadyPushJob.perform_now(@request.id) }

    assert_equal 0, count
  end

  test "pushes to every device the user has" do
    DeviceToken.register!(user: @user, token: "b" * 64, environment: "sandbox")
    sent = 0

    stub_push(->(_d, _p) { sent += 1; ok }) { SendImportReadyPushJob.perform_now(@request.id) }

    assert_equal 2, sent
  end

  test "never pushes to another user's device" do
    other = User.create!(email: "other-push@example.com", password: "password123", confirmed_at: Time.zone.now)
    DeviceToken.register!(user: other, token: "c" * 64)
    sent = []

    stub_push(->(device, _p) { sent << device; ok }) { SendImportReadyPushJob.perform_now(@request.id) }

    assert_equal [ @device ], sent
  end

  # Apple says the install is gone.
  test "a 410 invalidates the token rather than deleting it" do
    stub_push(->(_d, _p) { dead(410, "Unregistered") }) { SendImportReadyPushJob.perform_now(@request.id) }

    assert_not @device.reload.active?
    assert_equal 1, DeviceToken.count, "the row must survive so the history does"
  end

  test "a transient failure leaves the device alone" do
    stub_push(->(_d, _p) { failed(503, "ServiceUnavailable") }) { SendImportReadyPushJob.perform_now(@request.id) }

    assert @device.reload.active?, "a 503 says nothing about the token"
  end

  test "an invalidated device is skipped" do
    @device.invalidate!
    count = 0

    stub_push(->(_d, _p) { count += 1; ok }) { SendImportReadyPushJob.perform_now(@request.id) }

    assert_equal 0, count
  end

  # One bad device must not take the batch down with it.
  test "a device that raises does not stop the others" do
    good = DeviceToken.register!(user: @user, token: "d" * 64)
    delivered = []

    stub_push(lambda { |device, _p|
      raise "connection reset" if device.id == @device.id

      delivered << device
      ok
    }) { SendImportReadyPushJob.perform_now(@request.id) }

    assert_equal [ good ], delivered
    assert_not_nil @request.reload.notified_at
  end

  # Otherwise a user who never granted permission accrues a retry forever.
  test "an import for a user with no devices is marked notified" do
    @user.device_tokens.destroy_all

    stub_push(->(_d, _p) { flunk "should not push" }) { SendImportReadyPushJob.perform_now(@request.id) }

    assert_not_nil @request.reload.notified_at
  end

  test "does nothing when APNs is not configured" do
    Push::ApnsClient.stub(:configured?, false) do
      SendImportReadyPushJob.perform_now(@request.id)
    end

    assert_nil @request.reload.notified_at, "leave it unsent so it can go once a key exists"
  end

  test "a deleted import request is not an error" do
    assert_nothing_raised { SendImportReadyPushJob.perform_now(-1) }
  end

  test "publishing a course enqueues the push" do
    other = @user.import_requests.create!(
      youtube_url: "https://www.youtube.com/watch?v=bbbbbbbbbbb", youtube_video_id: "bbbbbbbbbbb",
      clip_language: "Spanish", translation_language: "English", title: "Another",
      status: :importing, course: @course, charged: true
    )

    assert_enqueued_with(job: SendImportReadyPushJob) do
      CreateCourseJob.new.send(:complete_imports!, @course)
    end

    assert other.reload.ready?
  end

  private

  def ok = Push::ApnsClient::Result.new(ok: true, status: 200, reason: nil)
  def dead(status, reason) = Push::ApnsClient::Result.new(ok: false, status: status, reason: reason)
  def failed(status, reason) = Push::ApnsClient::Result.new(ok: false, status: status, reason: reason)

  def stub_push(handler, &block)
    Push::ApnsClient.stub(:configured?, true) do
      Push::ApnsClient.stub(:push, handler, &block)
    end
  end
end
