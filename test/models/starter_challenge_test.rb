require "test_helper"

class StarterChallengeTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "starter@example.test", password: "password123", confirmed_at: Time.zone.now)
  end

  def enroll(languages = [languages(:french).id], delivery: [], reminder_time: "09:00", reminder_timezone: "UTC")
    StarterChallenge.enroll!(user: @user, language_ids: languages, delivery: delivery, reminder_time: reminder_time, reminder_timezone: reminder_timezone)
  end

  test "enrollment creates five dated quests and retains multiple target languages" do
    travel_to Time.zone.local(2026, 9, 24, 10) do
      challenge = enroll([languages(:french).id, languages(:spanish).id], delivery: %w[email push])
      assert_equal %w[fr es].sort, challenge.languages.pluck(:iso_name).sort
      assert_equal %w[email push], @user.reload.notification_delivery
      assert_equal (1..5).to_a, challenge.daily_challenges.order(:day).pluck(:day)
      assert_equal (0..4).map { |n| Time.utc(2026, 9, 25 + n, 9) }, challenge.daily_challenges.order(:day).pluck(:available_at)
      assert_equal DailyChallenge::QUESTS, challenge.daily_challenges.order(:day).map(&:quest)
      assert_equal 6, @user.credit_balance
    end
  end

  test "repeat enrollment and language edits do not reset the schedule or completion" do
    challenge = enroll
    day = challenge.daily_challenges.find_by!(day: 1)
    travel_to(day.available_at + 1.second) { day.complete! }
    original_start = challenge.started_at
    travel_to challenge.daily_challenges.find_by!(day: 3).available_at do
      assert_no_difference ["StarterChallenge.count", "DailyChallenge.count"] do
        repeated = enroll([languages(:spanish).id])
        assert_equal challenge.id, repeated.id
      end
    end
    assert_equal original_start, challenge.reload.started_at
    assert day.reload.completed_at?
    assert_equal [languages(:spanish).id], challenge.language_ids
  end

  test "invalid empty and mixed language selections do not mutate preferences or enroll" do
    [[], [""], ["bogus"], [languages(:french).id, "-1"]].each do |ids|
      assert_no_difference ["StarterChallenge.count", "DailyChallenge.count"] do
        assert_raises(ArgumentError) { enroll(ids, delivery: ["email"]) }
      end
      assert_equal ["push"], @user.reload.notification_delivery
    end
  end

  test "duplicate language ids are normalized and an empty delivery choice is retained" do
    challenge = enroll(["", languages(:french).id, languages(:french).id.to_s])
    assert_equal 1, challenge.languages.count
    assert_equal [], @user.reload.notification_delivery
  end

  test "only unlocked quests can be completed and completion is idempotent" do
    challenge = enroll
    first, second = challenge.daily_challenges.order(:day).first(2)
    assert_raises(ArgumentError) { second.complete! }
    travel_to(first.available_at + 1.second) { first.complete! }
    stamp = first.reload.completed_at
    travel_to first.available_at + 1.hour do
      first.complete!
      assert_equal stamp, first.reload.completed_at
    end
  end

  test "deleting an account removes its enrollment and quests including notified ones" do
    challenge = enroll
    travel_to(challenge.daily_challenges.first.available_at) { challenge.daily_challenges.first.notify! }
    assert_difference "DailyChallenge.count", -5 do
      assert_difference "StarterChallenge.count", -1 do
        @user.destroy!
      end
    end
  end

  test "unique day and supported day range are enforced" do
    challenge = enroll
    assert_not challenge.daily_challenges.new(day: 1, available_at: Time.zone.now).valid?
    assert_not challenge.daily_challenges.new(day: 6, available_at: Time.zone.now).valid?
  end
end
