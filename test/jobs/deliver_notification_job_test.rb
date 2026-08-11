require "test_helper"
require "minitest/mock"

# Delivery: which channels a notification goes out on, and what happens when
# one of them fails. The APNs cases here are the ones that used to live in
# send_import_ready_push_job_test.rb.
class DeliverNotificationJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @user = User.create!(email: "deliver@example.com", password: "password123", confirmed_at: Time.zone.now)
    @device = DeviceToken.register!(user: @user, token: "a" * 64)
    @notification = Notification.create!(
      user: @user, kind: :course_ready, data: { "video_title" => "Despacito", "count" => 2 }
    )
  end

  # --------------------------------------------------------------- channels

  test "the default is email and push" do
    sent = 0

    assert_emails 1 do
      stub_push(->(_d, _p) { sent += 1; ok }) { perform }
    end

    assert_equal 1, sent
    assert_not_nil @notification.reload.sent_at
  end

  test "email only sends no push" do
    @user.update!(notification_delivery: [ "email" ])

    assert_emails 1 do
      stub_push(->(_d, _p) { flunk "should not push" }) { perform }
    end
  end

  test "push only sends no email" do
    @user.update!(notification_delivery: [ "push" ])
    sent = 0

    assert_emails 0 do
      stub_push(->(_d, _p) { sent += 1; ok }) { perform }
    end

    assert_equal 1, sent
  end

  test "a failed import sends only the generic notification email" do
    notification = Notification.create!(
      user: @user,
      kind: :course_failed,
      data: { "video_title" => "Broken Song", "reason" => "Word translation count mismatch" }
    )

    assert_emails 1 do
      DeliverNotificationJob.perform_now(notification.id)
    end

    user_email = ActionMailer::Base.deliveries.last
    assert_equal [ @user.email ], user_email.to
    assert_includes user_email.text_part.body.decoded, "We're looking into it"
    assert_not_includes user_email.text_part.body.decoded, "Word translation count mismatch"
  end

  # A push-only user with no device is the ordinary case for anyone who never
  # granted iOS permission: nothing goes out, and the notification is still on
  # /notifications. It must not be left to retry forever.
  test "a channel with nothing to deliver to is still stamped as attempted" do
    @user.update!(notification_delivery: [ "push" ])
    @user.device_tokens.destroy_all

    assert_emails 0 do
      stub_push(->(_d, _p) { flunk "no devices to push to" }) { perform }
    end

    assert_not_nil @notification.reload.sent_at
  end

  # Every channel off — expressible now that the preference is a list. Same rule
  # as above: nothing goes out, the notification is still on /notifications, and
  # the job is done rather than pending forever.
  test "a user who wants no channels is still stamped as attempted" do
    @user.update!(notification_delivery: [])

    assert_emails 0 do
      stub_push(->(_d, _p) { flunk "should not push" }) { perform }
    end

    assert_not_nil @notification.reload.sent_at
  end

  # ------------------------------------------------------------ idempotency

  test "a re-run does not deliver twice" do
    sent = 0

    assert_emails 1 do
      stub_push(->(_d, _p) { sent += 1; ok }) do
        perform
        perform
      end
    end

    assert_equal 1, sent
  end

  test "a deleted notification is not an error" do
    assert_nothing_raised { DeliverNotificationJob.perform_now(-1) }
  end

  # -------------------------------------------------------------- isolation

  # Neither channel may take the other down with it.
  test "a mailer failure still lets the push through" do
    sent = 0

    NotificationMailer.stub(:notify, ->(*) { raise "SMTP is down" }) do
      stub_push(->(_d, _p) { sent += 1; ok }) { perform }
    end

    assert_equal 1, sent
    assert_not_nil @notification.reload.sent_at
  end

  test "a push failure still lets the email through" do
    assert_emails 1 do
      Push::Notifier.stub(:call, ->(*) { raise "APNs exploded" }) { perform }
    end

    assert_not_nil @notification.reload.sent_at
  end

  # ------------------------------------------------------------------ APNs

  test "the payload carries the copy, the deep link and the unread badge" do
    Notification.create!(user: @user, kind: :pro_activated)
    @notification.update!(
      url: "/courses/despacito",
      data: { "video_title" => "Despacito", "count" => 2, "course_slug" => "despacito" }
    )
    captured = nil

    stub_push(->(_device, payload) { captured = payload; ok }) { perform }

    assert_equal "“Despacito” is ready!", captured[:alert][:title]
    assert_equal "“Despacito” is now 2 lessons. Tap to start practicing.", captured[:alert][:body]
    assert_equal "despacito", captured[:custom_payload][:course_slug]
    assert_equal "/courses/despacito", captured[:custom_payload][:url]
    assert_equal 2, captured[:badge], "every unread notification, not just this one"
  end

  test "reading everything empties the badge" do
    Notification.mark_all_read!(@user)
    @notification.update_columns(read_at: nil) # the one being delivered is still unread
    captured = nil

    stub_push(->(_device, payload) { captured = payload; ok }) { perform }

    assert_equal 1, captured[:badge]
  end

  test "pushes to every device the user has" do
    DeviceToken.register!(user: @user, token: "b" * 64, environment: "sandbox")
    sent = 0

    stub_push(->(_d, _p) { sent += 1; ok }) { perform }

    assert_equal 2, sent
  end

  test "never pushes to another user's device" do
    other = User.create!(email: "other-deliver@example.com", password: "password123", confirmed_at: Time.zone.now)
    DeviceToken.register!(user: other, token: "c" * 64)
    sent = []

    stub_push(->(device, _p) { sent << device; ok }) { perform }

    assert_equal [ @device ], sent
  end

  # Apple says the install is gone.
  test "a 410 invalidates the token rather than deleting it" do
    stub_push(->(_d, _p) { result(410, "Unregistered") }) { perform }

    assert_not @device.reload.active?
    assert_equal 1, DeviceToken.count, "the row must survive so the history does"
  end

  test "a transient failure leaves the device alone" do
    stub_push(->(_d, _p) { result(503, "ServiceUnavailable") }) { perform }

    assert @device.reload.active?, "a 503 says nothing about the token"
  end

  test "an invalidated device is skipped" do
    @device.invalidate!
    count = 0

    stub_push(->(_d, _p) { count += 1; ok }) { perform }

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
    }) { perform }

    assert_equal [ good ], delivered
    assert_not_nil @notification.reload.sent_at
  end

  test "an unconfigured APNs key still lets the email out" do
    assert_emails 1 do
      Push::ApnsClient.stub(:configured?, false) { perform }
    end

    assert_not_nil @notification.reload.sent_at
  end

  private

  def perform = DeliverNotificationJob.perform_now(@notification.id)

  def ok = Push::ApnsClient::Result.new(ok: true, status: 200, reason: nil)
  def result(status, reason) = Push::ApnsClient::Result.new(ok: false, status: status, reason: reason)

  def stub_push(handler, &block)
    Push::ApnsClient.stub(:configured?, true) do
      Push::ApnsClient.stub(:push, handler, &block)
    end
  end
end
