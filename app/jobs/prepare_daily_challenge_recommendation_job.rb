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
      if quest.recommendation_state == "importing"
        quest.update!(search_started_at: Time.zone.now)
        next :import
      end
      if quest.search_attempts >= 3
        quest.update!(recommendation_state: "failed", recommendation_failure: "Preparation did not complete")
        return
      end
      quest.update!(recommendation_state: "searching", search_started_at: Time.zone.now,
        search_attempts: quest.search_attempts + 1)
      :search
    end
    return unless claimed

    if claimed == :search
      recommendation = DailyVideoRecommendation.call(user: quest.starter_challenge.user, language: quest.language)
      video = recommendation.video || Imports::VideoPreflight.call(recommendation.url).video
      quest.with_lock do
        quest.update!(recommendation_state: "importing", recommendation_failure: nil,
          recommended_video: { "url" => video.canonical_url, "title" => video.title.to_s.truncate(200),
            "thumbnail_url" => video.thumbnail_url, "search_suggestions" => recommendation.search_suggestions,
            "channel" => video.author_name, "content_type" => recommendation.content_type })
      end
    end
    prepare_course(quest)
  rescue StandardError => error
    if quest
      quest.with_lock do
        quest.update!(recommendation_state: quest.recommendation_state == "importing" || quest.search_attempts >= 3 ? "failed" : "pending",
          search_started_at: nil, recommendation_failure: error.class.name.truncate(250)) unless quest.notification_id.present?
      end
      Rails.logger.error "Daily challenge recommendation #{quest.id} failed: #{error.class}"
    end
  end

  private

  def prepare_course(quest)
    source = ImportRequest.find_by(id: quest.recommended_video["source_import_request_id"])
    unless source
      result = Imports::Create.call(user: User.find_by!(email: User::ADMIN_EMAIL),
        url: quest.recommended_video.fetch("url"), clip_language: quest.language.english_name,
        translation_language: quest.starter_challenge.user.native_language.english_name,
        guest_started: true)
      source = result.import_request
      quest.with_lock do
        quest.update!(recommended_video: quest.recommended_video.merge("source_import_request_id" => source.id))
      end
    end

    ready = source.ready? && source.course&.published? &&
      source.course.translation_ready?(Language.find_by!(english_name: source.translation_language))
    failed = source.failed? || source.canceled? || (source.ready? && !ready)
    quest.with_lock do
      quest.update!(recommendation_state: ready ? "ready" : (failed ? "failed" : "importing"),
        search_started_at: nil, recommendation_failure: failed ? "Recommended course preparation failed" : nil)
    end
    quest.notify! if ready
  end
end
