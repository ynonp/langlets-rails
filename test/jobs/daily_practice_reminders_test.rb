require "test_helper"

class DailyPracticeRemindersTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    travel_to Time.zone.local(2026, 9, 24, 12)
    @user = User.create!(email: "daily-practice@example.test", password: "password123", confirmed_at: Time.zone.now)
    @challenge = StarterChallenge.enroll!(user: @user, language_ids: [languages(:arabic).id],
      delivery: ["email"], reminder_time: "18:30", reminder_timezone: "Europe/Berlin")
  end

  test "first quest arrives tomorrow at the chosen local time and practice follows day five" do
    assert_equal Date.new(2026, 9, 25), @challenge.first_challenge_on
    assert_equal Time.utc(2026, 9, 25, 16, 30), @challenge.daily_challenges.find_by!(day: 1).available_at
    travel_to @challenge.daily_challenges.find_by!(day: 1).available_at - 1.second do
      assert_no_difference "Notification.count" do
        SendDailyChallengesJob.perform_now
      end
    end
    travel_to @challenge.daily_challenges.find_by!(day: 1).available_at do
      assert_difference "Notification.kind_daily_challenge.count", 1 do
        SendDailyChallengesJob.perform_now
      end
    end
    practice_time = @challenge.local_time_on(@challenge.first_challenge_on + 5)
    travel_to practice_time - 1.second do
      assert_no_difference "DailyPracticeReminder.count" do
        SendDailyChallengesJob.perform_now
      end
    end
    travel_to practice_time do
      assert_difference "DailyPracticeReminder.count", 1 do
        2.times { SendDailyChallengesJob.perform_now }
      end
      reminder = @challenge.daily_practice_reminders.last
      assert_equal "/daily_practice?language_code=ar-JO", reminder.notification.url
      assert_equal "Time to practice Arabic", reminder.notification.title(locale: :en)
      assert_emails(1) { DeliverNotificationJob.perform_now(reminder.notification.id) }
    end
    travel_to practice_time + 1.day do
      assert_difference "DailyPracticeReminder.count", 1 do
        SendDailyChallengesJob.perform_now
      end
    end
  end

  test "practice follows local calendar dates across daylight saving change" do
    travel_to Time.zone.local(2026, 10, 24, 12) do
      user = User.create!(email: "daily-dst@example.test", password: "password123")
      challenge = StarterChallenge.enroll!(user: user, language_ids: [languages(:french).id], delivery: [],
        reminder_time: "18:30", reminder_timezone: "Europe/Berlin")
      assert_equal Time.utc(2026, 10, 25, 17, 30), challenge.daily_challenges.first.available_at
      assert_equal Time.utc(2026, 10, 26, 17, 30), challenge.daily_challenges.second.available_at
    end
  end

  test "outage does not send a backlog of missed practice reminders" do
    travel_to @challenge.local_time_on(@challenge.first_challenge_on + 15) do
      assert_difference "DailyPracticeReminder.count", 1 do
        SendDailyChallengesJob.perform_now
      end
      assert_equal [@challenge.local_today], @challenge.daily_practice_reminders.pluck(:local_date)
    end
  end

  test "an undelivered practice reminder is not emailed after its local date" do
    travel_to @challenge.local_time_on(@challenge.first_challenge_on + 5) do
      DailyPracticeReminder.deliver_due!(@challenge)
    end
    notification = @challenge.daily_practice_reminders.last.notification
    travel_to @challenge.local_time_on(@challenge.first_challenge_on + 6) do
      assert_emails(0) { DeliverNotificationJob.perform_now(notification.id) }
      assert notification.reload.sent_at?
    end
  end

  test "changing reminder time reschedules future unsent quests without restarting enrollment" do
    original_start = @challenge.started_at
    original_first = @challenge.first_challenge_on
    StarterChallenge.enroll!(user: @user, language_ids: [languages(:arabic).id], delivery: [],
      reminder_time: "07:15", reminder_timezone: "Europe/Berlin")
    assert_equal original_start, @challenge.reload.started_at
    assert_equal original_first, @challenge.first_challenge_on
    assert_equal Time.utc(2026, 9, 25, 5, 15), @challenge.daily_challenges.first.reload.available_at
  end
end
