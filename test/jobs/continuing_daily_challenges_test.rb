require "test_helper"

class ContinuingDailyChallengesTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    travel_to Time.zone.local(2026, 9, 24, 12)
    @user = User.create!(email: "continuing@example.test", password: "password123")
    @challenge = StarterChallenge.enroll!(user: @user, language_ids: [ languages(:arabic).id ], delivery: [ "email" ],
      reminder_time: "18:30", reminder_timezone: "Europe/Berlin")
  end

  test "personalized challenges follow day five and start preparing thirty minutes before reminder time" do
    time = @challenge.local_time_on(@challenge.first_challenge_on + 5)
    travel_to time - 31.minutes
    assert_no_difference("DailyChallenge.count") { SendDailyChallengesJob.perform_now }
    travel_to time - 30.minutes
    assert_difference "DailyChallenge.count", 1 do
      2.times { SendDailyChallengesJob.perform_now }
    end
    quest = @challenge.daily_challenges.find_by!(day: 6)
    assert_equal time, quest.available_at
    assert_equal languages(:arabic), quest.language
    assert_nil quest.notification
    assert_equal 0, DailyPracticeReminder.count
    assert_enqueued_with(job: PrepareDailyChallengeRecommendationJob, args: [ quest.id ])
    travel_to time + 1.day
    assert_difference "DailyChallenge.count", 1 do
      SendDailyChallengesJob.perform_now
    end
    assert @challenge.daily_challenges.find_by!(day: 7).personalized?
  end

  test "an outage creates only today's continuing challenge" do
    travel_to @challenge.local_time_on(@challenge.first_challenge_on + 15)
    assert_difference "DailyChallenge.count", 1 do
      SendDailyChallengesJob.perform_now
    end
    assert_equal [ 16 ], @challenge.daily_challenges.where("day > 5").pluck(:day)
  end

  test "challenge times preserve local hour across daylight saving change" do
    travel_to Time.zone.local(2026, 10, 19, 12)
    challenge = StarterChallenge.enroll!(user: @user, language_ids: [ languages(:french).id ], delivery: [],
      reminder_time: "18:30", reminder_timezone: "Europe/Berlin")
    # Existing enrollment keeps its date; the scheduler still uses the selected local calendar.
    travel_to Time.utc(2026, 10, 24, 16, 20)
    first = DailyChallenge.ensure_personalized_today!(challenge)
    travel_to Time.utc(2026, 10, 25, 17, 20)
    second = DailyChallenge.ensure_personalized_today!(challenge)
    assert_equal Time.utc(2026, 10, 24, 16, 30), first.available_at
    assert_equal Time.utc(2026, 10, 25, 17, 30), second.available_at
  end

  test "historical practice reminders are no longer delivered" do
    travel_to @challenge.local_time_on(@challenge.first_challenge_on + 5)
    notification = Notifications.deliver(user: @user, kind: :daily_practice, language_code: "ar-JO", language_name: "Arabic")
    @challenge.daily_practice_reminders.create!(local_date: @challenge.local_today, notification: notification)
    assert_emails(0) { DeliverNotificationJob.perform_now(notification.id) }
    assert notification.reload.sent_at?
  end
end
