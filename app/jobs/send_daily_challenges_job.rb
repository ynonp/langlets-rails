class SendDailyChallengesJob < ApplicationJob
  queue_as :default

  def perform
    Notification.where(kind: :daily_challenge, sent_at: nil).find_each do |notification|
      DeliverNotificationJob.perform_later(notification.id)
    end
    StarterChallenge.where(next_practice_at: ..(Time.zone.now + DailyChallenge::PREPARATION_LEAD)).find_each do |challenge|
      DailyChallenge.ensure_personalized_today!(challenge)
    end
    DailyChallenge.due.find_each(&:notify!)
    DailyChallenge.recommendations_to_prepare.find_each do |quest|
      PrepareDailyChallengeRecommendationJob.perform_later(quest.id)
    end
  end
end
