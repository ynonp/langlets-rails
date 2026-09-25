class DailyChallenge < ApplicationRecord
  QUESTS = %w[song vocabulary story tiktok skim].freeze
  belongs_to :starter_challenge
  belongs_to :notification, optional: true
  validates :day, inclusion: { in: 1..5 }, uniqueness: { scope: :starter_challenge_id }
  validates :available_at, presence: true

  scope :due, -> { where(available_at: ..Time.zone.now, notification_id: nil, skipped_at: nil) }

  def quest = QUESTS.fetch(day - 1)
  def unlocked? = available_at <= Time.zone.now && day == starter_challenge.active_day

  def complete!
    with_lock do
      raise ArgumentError, 'Quest is not available yet' unless unlocked?
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
      if starter_challenge.daily_challenges.where('day > ?', day).where(available_at: ..Time.zone.now).exists?
        update!(skipped_at: Time.zone.now)
      else
        update!(notification: Notifications.deliver(user: starter_challenge.user, kind: :daily_challenge, day: day))
      end
    end
  end
end
