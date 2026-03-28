class ReviewLessonsController < ApplicationController
  include Xp
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
    add_lesson_xp

    @course_path = root_path
    @next_lesson = nil
    @continue_path = root_path

    render "lessons/finish"
  end
end
