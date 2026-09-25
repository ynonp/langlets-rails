require "test_helper"

class SendDailyChallengesJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    travel_to Time.zone.local(2026, 9, 24, 10)
    @user = User.create!(email: "quests@example.test", password: "password123", confirmed_at: Time.zone.now)
    @challenge = StarterChallenge.enroll!(user: @user, language_ids: [languages(:french).id], delivery: ["email"])
  end

  test "five days send one notification each with stable links and no sixth day" do
    (0..4).each do |offset|
      travel_to @challenge.daily_challenges.find_by!(day: offset + 1).available_at do
        assert_difference "Notification.count", 1 do
          2.times { SendDailyChallengesJob.perform_now }
        end
          notification = @challenge.daily_challenges.find_by!(day: offset + 1).notification
          assert_equal @user, notification.user
          assert_equal "/daily_challenge#day-#{offset + 1}", notification.url
          assert_equal offset + 1, notification.data["day"]
          assert_emails(1) { 2.times { DeliverNotificationJob.perform_now(notification.id) } }
          assert notification.reload.sent_at?
      end
    end
  end

  test "day two does not send before its exact unlock time" do
    travel_to @challenge.daily_challenges.find_by!(day: 1).available_at { SendDailyChallengesJob.perform_now }
    travel_to @challenge.daily_challenges.find_by!(day: 2).available_at - 1.second do
      assert_no_difference "Notification.count" do
        SendDailyChallengesJob.perform_now
      end
    end
  end

  test "outage skips stale reminders instead of sending a burst" do
    travel_to @challenge.daily_challenges.find_by!(day: 4).available_at do
      assert_difference "Notification.count", 1 do
        SendDailyChallengesJob.perform_now
      end
      assert_equal [1, 2, 3], @challenge.daily_challenges.where.not(skipped_at: nil).order(:day).pluck(:day)
      assert @challenge.daily_challenges.find_by!(day: 4).notification
      assert_nil @challenge.daily_challenges.find_by!(day: 5).notification
    end
  end

  test "a lost enqueue is recovered from the notification record" do
    travel_to @challenge.daily_challenges.first.available_at
    @challenge.daily_challenges.first.notify!
    clear_enqueued_jobs
    assert_enqueued_with(job: DeliverNotificationJob) do
      assert_no_difference "Notification.count" do
        SendDailyChallengesJob.perform_now
      end
    end
  end

  test "an undelivered quest reminder is not emailed on the next day" do
    travel_to @challenge.daily_challenges.first.available_at do
      @challenge.daily_challenges.first.notify!
    end
    notification = @challenge.daily_challenges.first.notification
    travel_to @challenge.daily_challenges.second.available_at do
      assert_emails(0) { DeliverNotificationJob.perform_now(notification.id) }
      assert notification.reload.sent_at?
    end
  end

  test "delivery reads current preferences including neither email nor push" do
    travel_to @challenge.daily_challenges.first.available_at
    SendDailyChallengesJob.perform_now
    notification = @user.notifications.last
    @user.update!(notification_delivery: [])
    Push::Notifier.stub(:call, ->(*) { flunk "push disabled" }) do
      assert_emails(0) { DeliverNotificationJob.perform_now(notification.id) }
    end
    assert notification.reload.sent_at?
  end

  test "push only and both channels use the existing notifier" do
    travel_to @challenge.daily_challenges.first.available_at
    notification = @challenge.daily_challenges.first.tap(&:notify!).notification
    [ ["push"], %w[email push] ].each do |channels|
      notification.reload.update!(sent_at: nil)
      @user.update!(notification_delivery: channels)
      calls = []
      Push::Notifier.stub(:call, ->(row) { calls << row.id }) do
        assert_emails(channels.include?("email") ? 1 : 0) { DeliverNotificationJob.perform_now(notification.id) }
      end
      assert_equal [notification.id], calls
    end
  end

  test "notification explains the particular quest in every interface locale" do
    (1..5).each do |day|
      notification = Notifications.deliver(user: @user, kind: :daily_challenge, day: day)
      I18n.available_locales.each do |locale|
        body = notification.body(locale: locale)
        assert_includes body, I18n.t("daily_challenge.quests.#{DailyChallenge::QUESTS[day - 1]}.title", locale: locale)
        assert_not_includes body, "Translation missing"
      end
    end
  end
end
