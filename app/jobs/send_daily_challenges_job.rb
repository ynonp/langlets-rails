class SendDailyChallengesJob < ApplicationJob
  queue_as :default

  def perform
    # Recover a commit followed by a process/queue outage before enqueue. The
    # delivery job locks and checks sent_at, so duplicate enqueues are harmless.
    Notification.where(kind: [ :daily_challenge, :daily_practice ]).where(sent_at: nil).find_each do |notification|
      DeliverNotificationJob.perform_later(notification.id)
    end
    DailyChallenge.due.find_each(&:notify!)
    StarterChallenge.where(next_practice_at: ..Time.zone.now).find_each do |challenge|
      DailyPracticeReminder.deliver_due!(challenge)
    end
  end
end
