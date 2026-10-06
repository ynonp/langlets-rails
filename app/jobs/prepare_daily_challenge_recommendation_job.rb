class PrepareDailyChallengeRecommendationJob < ApplicationJob
  queue_as :default
  self.enqueue_after_transaction_commit = true

  def perform(quest_id)
    quest = DailyChallenge.find_by(id: quest_id)
    return unless quest&.personalized?
    claimed = quest.with_lock do
      return if quest.notification_id.present? || quest.skipped_at.present? || quest.recommendation_state.in?(%w[ready failed])
      if quest.day != quest.starter_challenge.active_day
        quest.update!(skipped_at: Time.zone.now)
        return
      end
      return if quest.available_at > Time.zone.now + DailyChallenge::PREPARATION_LEAD
      return if quest.search_started_at && quest.search_started_at > Time.zone.now - DailyChallenge::SEARCH_LEASE
      if quest.search_attempts >= 3
        quest.update!(recommendation_state: "failed", recommendation_failure: "Preparation did not complete")
        return
      end
      quest.update!(recommendation_state: "searching", search_started_at: Time.zone.now,
        search_attempts: quest.search_attempts + 1)
      true
    end
    return unless claimed

    recommendation = DailyVideoRecommendation.call(user: quest.starter_challenge.user, language: quest.language)
    video = recommendation.video || Imports::VideoPreflight.call(recommendation.url).video
    quest.with_lock do
      quest.update!(recommendation_state: "ready", recommendation_failure: nil,
        recommended_video: { "url" => video.canonical_url, "title" => video.title.to_s.truncate(200),
          "thumbnail_url" => video.thumbnail_url, "search_suggestions" => recommendation.search_suggestions,
          "channel" => video.author_name, "content_type" => recommendation.content_type })
    end
    quest.notify!
  rescue StandardError => error
    if quest
      quest.with_lock do
        quest.update!(recommendation_state: quest.search_attempts >= 3 ? "failed" : "pending",
          search_started_at: nil, recommendation_failure: error.class.name.truncate(250)) unless quest.notification_id.present?
      end
      Rails.logger.error "Daily challenge recommendation #{quest.id} failed: #{error.class}"
    end
  end
end
