class ActivityLog < ApplicationRecord
  belongs_to :user
  belongs_to :lesson, optional: true

  validates :active_time, :xp_gained, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # XP calculation methods
  def self.daily_xp_for_user(user, date = Date.current)
    where(user: user, created_at: date.beginning_of_day..date.end_of_day)
      .sum(:xp_gained)
  end

  def self.total_xp_for_user(user)
    where(user: user).sum(:xp_gained)
  end

  # Streak calculation method
  def self.current_streak_for_user(user)
    # Get all lesson completion logs (where lesson_id is not nil) ordered by date
    lesson_logs = where(user: user)
                    .where.not(lesson_id: nil)
                    .select('DATE(created_at) as log_date')
                    .group('DATE(created_at)')
                    .order('DATE(created_at) DESC')
                    .pluck('DATE(created_at)')

    return 0 if lesson_logs.empty?

    current_streak = 0
    current_date = Date.current

    # Check each consecutive day going backwards
    lesson_logs.each do |log_date|
      if log_date == current_date || log_date == current_date - current_streak.days
        current_streak += 1
        current_date = log_date
      else
        break
      end
    end

    current_streak
  end

  # Create activity completion log
  def self.log_activity_completion(user:, active_time:, xp_gained:)
    create!(
      user: user,
      active_time: active_time,
      xp_gained: xp_gained,
      lesson: nil
    )
  end

  # Create lesson completion log
  def self.log_lesson_completion(user:, lesson:, active_time:, xp_gained:)
    create!(
      user: user,
      lesson: lesson,
      active_time: active_time,
      xp_gained: xp_gained
    )
  end
end
