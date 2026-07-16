class ActivityLog < ApplicationRecord
  belongs_to :user
  belongs_to :lesson, optional: true

  validates :active_time, :xp_gained, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # XP calculation methods
  def self.daily_xp_for_user(user, date = Time.zone.now.to_date)
    where(user: user, created_at: date.beginning_of_day..date.end_of_day)
      .sum(:xp_gained)
  end

  def self.total_xp_for_user(user)
    where(user: user).sum(:xp_gained)
  end

  # XP totals for each of the last `days` days, oldest first, including days
  # with no activity so the caller always gets a full series to chart.
  # Bucketed in Ruby against Time.zone rather than SQL DATE() so the days line
  # up with daily_xp_for_user, which uses zone-aware day boundaries.
  def self.daily_xp_series_for_user(user, days: 7)
    today = Time.zone.now.to_date
    first_day = today - (days - 1).days

    totals = where(user: user, created_at: first_day.beginning_of_day..today.end_of_day)
      .pluck(:created_at, :xp_gained)
      .each_with_object(Hash.new(0)) do |(created_at, xp), acc|
        acc[created_at.in_time_zone.to_date] += xp.to_i
      end

    (first_day..today).map { |date| { date: date, xp: totals[date] } }
  end

  # Streak calculation method
  def self.current_streak_for_user(user)
    streak_data = streak_info_for_user(user)
    streak_data[:count]
  end

  # Returns comprehensive streak information
  def self.streak_info_for_user(user)
    return ActivityLog.none if user.nil?

    # Get all lesson completion logs (where lesson_id is not nil) ordered by date
    lesson_logs = where(user: user)
                    .where.not(lesson_id: nil)
                    .select('DATE(created_at) as log_date')
                    .group('DATE(created_at)')
                    .order('DATE(created_at) DESC')
                    .pluck('DATE(created_at)')

    today = Time.zone.now.to_date
    completed_today = lesson_logs.include?(today)

    if lesson_logs.empty?
      return {
        count: 0,
        completed_today: false,
        status: :no_streak
      }
    end

    # Calculate streak starting from most recent day
    current_streak = 0
    check_date = completed_today ? today : today - 1.day

    lesson_logs.each do |log_date|
      if log_date == check_date
        current_streak += 1
        check_date -= 1.day
      else
        break
      end
    end

    # Determine status
    status = if completed_today
               :completed_today    # Orange background - today's lesson done
             elsif current_streak > 0
               :at_risk           # Lighter background - streak at risk
             else
               :no_streak         # Orange background - no active streak
             end

    {
      count: current_streak,
      completed_today: completed_today,
      status: status
    }
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
