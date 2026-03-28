module Xp
  extend ActiveSupport::Concern

  def add_lesson_xp
    @lesson_xp = @lesson.activities.sum(&:xp_value)

    @daily_xp = ActivityLog.daily_xp_for_user(current_user)
    @total_xp = ActivityLog.total_xp_for_user(current_user)
    @current_streak = ActivityLog.current_streak_for_user(current_user)

    today = Time.zone.now.to_date
    last_lesson_today = ActivityLog.where(user: current_user)
      .where.not(lesson_id: nil)
      .where(created_at: today.beginning_of_day..today.end_of_day)
      .exists?
    @first_lesson_today = !last_lesson_today
  end
end
