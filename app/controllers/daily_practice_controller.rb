class DailyPracticeController < ApplicationController
  before_action :authenticate_user!

  def show
    challenge = current_user.starter_challenge
    raise ActiveRecord::RecordNotFound unless challenge&.practice_started?

    language = challenge.languages.find_by(iso_name: params[:language_code]) || challenge.practice_language
    if current_user.languages_with_saved_words.where(id: language.id).exists?
      return redirect_to review_lessons_path(language_code: language.iso_name)
    end

    visible_courses = ChannelContentQuery.courses_visible_to(current_user).published.select(:id)
    course = current_user.enrollments.where(course_id: visible_courses)
      .includes(:course).order(last_practiced_at: :desc).to_a.find do |enrollment|
      enrollment.course.first_incomplete_lesson_id_for(current_user).present?
    end&.course
    if course
      redirect_to course_lesson_path(course, course.first_incomplete_lesson_id_for(current_user))
    else
      redirect_to daily_challenge_path, alert: t("daily_challenge.no_daily_lesson")
    end
  end
end
