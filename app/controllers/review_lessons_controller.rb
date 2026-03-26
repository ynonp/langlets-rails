class ReviewLessonsController < ApplicationController
  before_action :authenticate_user!

  def create
    lesson = ReviewLessonBuilder.new(current_user).build!
    redirect_to review_lesson_path(lesson)
  end

  def show
    @lesson = current_user.lessons.find(params[:id])
    @activities = @lesson.activities.order(order: :asc).load
    @activity = @activities.find { |a| a.order == params[:a].to_i } || @activities.first

    @current_url = review_lesson_path(@lesson, a: @activity.order)

    next_activity = @lesson.activities.where("activities.order > ?", @activity.order).order(order: :asc).first

    @next_activity_path = if next_activity.present?
      review_lesson_path(@lesson, a: next_activity.order)
    else
      finish_review_lesson_path(@lesson)
    end

    @is_last_activity = next_activity.blank?

    @progress_data = {
      activity_id: @activity.id,
      lesson_id: (@activity.is_last_in_lesson? ? @lesson.id : nil),
      activity_xp: @activity.xp_value
    }.compact

    # Review lessons have no video
    @videoid = nil

    render "review_lessons/show"
  end

  def finish
    @lesson = current_user.lessons.find(params[:id])
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

    @course_path = root_path
    @next_lesson = nil
    @continue_path = root_path

    render "lessons/finish"
  end
end
