class DailyChallenge < ApplicationRecord
  PREPARATION_LEAD = 30.minutes
  SEARCH_LEASE = 10.minutes
  QUESTS = %w[song vocabulary story tiktok skim].freeze
  belongs_to :starter_challenge
  belongs_to :notification, optional: true
  belongs_to :language, optional: true
  validates :language, presence: true, if: :personalized?
  validates :recommendation_state, inclusion: { in: %w[pending searching ready failed] }
  validates :day, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :starter_challenge_id }
  validates :available_at, presence: true
  validate :complete_recommendation, if: -> { personalized? && recommendation_state == "ready" }

  scope :due, -> { where(available_at: ..Time.zone.now, notification_id: nil, skipped_at: nil) }

  scope :recommendations_to_prepare, -> {
    where("day > 5").where(notification_id: nil, skipped_at: nil, recommendation_state: %w[pending searching])
      .where(available_at: ..(Time.zone.now + PREPARATION_LEAD))
  }

  def personalized? = day.to_i > 5
  def quest = personalized? ? "recommendation" : QUESTS.fetch(day - 1)
  def unlocked? = available_at <= Time.zone.now && day == starter_challenge.active_day && (!personalized? || recommendation_state == "ready")

  def self.ensure_personalized_today!(challenge)
    challenge.with_lock do
      return unless challenge.practice_started?
      quest = challenge.daily_challenges.find_or_create_by!(day: challenge.active_day) do |daily|
        daily.available_at = challenge.local_time_on(challenge.local_today)
        daily.language = challenge.practice_language
      end
      challenge.update!(next_practice_at: challenge.local_time_on(challenge.local_today + 1))
      quest
    end
  end

  def videos_for(language_code, catalog: nil)
    if personalized?
      language.iso_name == language_code && recommendation_state == "ready" ? [ recommended_video ] : []
    else
      StarterChallengeCatalog.for(language_code, quest, catalog: catalog || StarterChallengeCatalog.all)
    end
  end

  def complete!
    with_lock do
      raise ArgumentError, "Quest is not available yet" unless unlocked?
      update!(completed_at: Time.zone.now) unless completed_at?
    end
  end

  def notify!
    with_lock do
      return if notification_id.present? || skipped_at.present?
      if day < starter_challenge.active_day
        update!(skipped_at: Time.zone.now)
        return
      end
      return unless unlocked?
      # After an outage, show all unlocked quests but send only the latest.
      if starter_challenge.daily_challenges.where("day > ?", day).where(available_at: ..Time.zone.now).exists?
        update!(skipped_at: Time.zone.now)
      else
        update!(notification: Notifications.deliver(user: starter_challenge.user, kind: :daily_challenge, day: day, title: recommended_video["title"]))
      end
    end
  end
  private

  def complete_recommendation
    unless recommended_video.is_a?(Hash) && recommended_video["url"].present? && recommended_video["title"].present?
      errors.add(:recommended_video, "must include a video URL and title")
    end
  end
end
