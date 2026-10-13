class ReviewLessonsController < ApplicationController
  include Xp
  before_action :authenticate_user!

  def show
    @lesson = current_user.current_review_lesson(params[:language_code], start: true)

    @activities = @lesson.activities.order(order: :asc).load
    @activity = @activities.find { |a| a.order == params[:a].to_i } || @activities.first

    @current_url = review_lessons_path(language_code: @lesson.review_language.iso_name, a: @activity.order)

    next_activity = @lesson.activities.where("activities.order > ?", @activity.order).order(order: :asc).first

    @next_activity_path = if next_activity.present?
      review_lessons_path(language_code: @lesson.review_language.iso_name, a: next_activity.order)
    else
      finish_review_lessons_path(language_code: @lesson.review_language.iso_name)
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
    @lesson = current_user.current_review_lesson(params[:language_code])
    was_finished = @lesson.review_finished?
    @lesson.update!(review_build_status: :finished) if @lesson.review_started?
    add_lesson_xp
    current_user.refresh_review_lesson!(@lesson.review_language)
    track_event("review_lesson_completed", lesson_id: @lesson.id, language: @lesson.review_language.iso_name) unless was_finished

    @course_path = root_path
    @next_lesson = nil
    @continue_path = root_path

    render "lessons/finish"
  end

  def recall
    activity = current_user.activities.find(params[:activity_id])
    lesson = activity.lesson
    return head :unprocessable_entity unless lesson.user_id == current_user.id && lesson.review_started? &&
      lesson.review_language_id.present? && activity.is_a?(Activities::WriteMissingWordActivity)
    return head :unprocessable_entity unless [ true, false ].include?(params[:remembered])

    token = activity.phrase_tokens.find(params[:phrase_token_id])
    entry = current_user.phrase_token_users.find_by(phrase_token: token)
    entry&.record_recall!(lesson: lesson, remembered: params[:remembered])
    head :no_content
  end
end
