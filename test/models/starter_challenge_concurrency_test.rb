require "test_helper"

class StarterChallengeConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  EMAIL = "starter-concurrency@example.test"

  setup do
    User.where(email: EMAIL).find_each(&:destroy!)
    @user = User.create!(email: EMAIL, password: "password123", confirmed_at: Time.zone.now)
  end

  teardown { User.where(email: EMAIL).find_each(&:destroy!) }

  test "simultaneous enrollment creates one schedule" do
    language_id = languages(:french).id
    race do
      StarterChallenge.enroll!(user: User.find(@user.id), language_ids: [language_id], delivery: [])
    end
    assert_equal 1, @user.reload.starter_challenge.daily_challenges.group(:starter_challenge_id).count.size
    assert_equal 5, @user.starter_challenge.daily_challenges.count
    assert_equal 1, StarterChallenge.where(user: @user).count
  end

  test "simultaneous schedulers create one notification" do
    challenge = StarterChallenge.enroll!(user: @user, language_ids: [languages(:french).id], delivery: [])
    day_id = challenge.daily_challenges.find_by!(day: 1).id
    travel_to(challenge.daily_challenges.first.available_at + 1.second) do
      race { DailyChallenge.find(day_id).notify! }
    end
    assert_equal 1, @user.notifications.where(kind: :daily_challenge).count
    assert_equal @user.notifications.last.id, DailyChallenge.find(day_id).notification_id
  end

  test "simultaneous daily practice schedulers create one reminder" do
    challenge = StarterChallenge.enroll!(user: @user, language_ids: [languages(:arabic).id], delivery: [])
    travel_to challenge.local_time_on(challenge.first_challenge_on + 5) do
      race { DailyPracticeReminder.deliver_due!(StarterChallenge.find(challenge.id)) }
    end
    assert_equal 1, challenge.daily_practice_reminders.count
    assert_equal 1, @user.notifications.where(kind: :daily_practice).count
  end

  test "simultaneous delivery workers attempt a channel once" do
    challenge = StarterChallenge.enroll!(user: @user, language_ids: [languages(:french).id], delivery: ["push"])
    day = challenge.daily_challenges.find_by!(day: 1)
    attempts = Queue.new
    travel_to(day.available_at + 1.second) do
      day.notify!
      Push::Notifier.stub(:call, ->(notification) { attempts << notification.id }) do
        notification_id = day.notification_id
        race { DeliverNotificationJob.perform_now(notification_id) }
      end
    end
    assert_equal 1, attempts.size
    assert day.notification.reload.sent_at?
  end

  private

  def race(&block)
    barrier = Concurrent::CyclicBarrier.new(2)
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          raise "concurrency barrier timed out" unless barrier.wait(10)
          block.call
        end
      end
    end
    threads.each(&:value)
  end
end
