class LessonsController < ApplicationController
  include Xp

  def show
    @course = Course.find_by(slug: params[:course_id]) || Course.find(params[:course_id])
    @lesson = @course.lessons
      .joins(medium: :language)
      .select("
              media.url as media_url,
              languages.iso_name as media_language,
              languages.rtl as rtl_language,
              lessons.*")
      .find_by!(slug: params[:id])
    
    video_url = @lesson.media_url
    @activities = @lesson.activities.order(order: :asc).load
    @activity = @activities.find {|a| a.order == params[:a].to_i } || @activities.first
    @current_url = course_lesson_path(@course, @lesson, a: @activity.order)
    @videoid = Medium.new(url: video_url).extract_youtube_video_id

    current_order = params[:a].to_i

    next_activity = @lesson.activities.where("activities.order > ?", @activity.order).order(order: :asc).first
    @course_path = course_path(@course.slug)

    # Previous and next lesson navigation
    @prev_lesson = @course.lessons.where("lessons.order < ?", @lesson.order).order(order: :desc).first
    @next_lesson = @course.lessons.where("lessons.order > ?", @lesson.order).order(order: :asc).first
    
    @next_activity_path = if next_activity.present?
      course_lesson_path(@course, @lesson, a: next_activity.order)
    else
      # After last activity, go to finish lesson page
      finish_course_lesson_path(@course, @lesson)
    end

    @is_last_activity = next_activity.blank?

    # Allow the browser to cache the activity frame so JS can prefetch the next
    # activity (see activity_navigation_controller.js) for an instant "Next" tap.
    # Scoped to Turbo-Frame requests only: full-page loads stay uncached, and the
    # frame body is a pure function of (lesson, activity order) with no per-user
    # state, so a 10-minute private cache can't serve anything stale.
    if request.headers["Turbo-Frame"].present?
      response.headers["Cache-Control"] = "private, max-age=600"
      response.headers["Vary"] = [ response.headers["Vary"], "Turbo-Frame" ].compact.join(", ")
    end

    # Prepare progress data for completion messages
    @progress_data = {
      activity_id: @activity.id,
      lesson_id: (@activity.is_last_in_lesson? ? @lesson.id : nil),
      activity_xp: @activity.xp_value
    }.compact
  end

  def finish
    @course = Course.find_by(slug: params[:course_id]) || Course.find(params[:course_id])
    @lesson = @course.lessons.find_by(slug: params[:id]) || @course.lessons.find(params[:id])

    # Calculate XP earned in this lesson
    @lesson_xp = @lesson.activities.sum(&:xp_value)
    
    # Get user stats from ActivityLog (only for authenticated users)
    if current_user
      LessonUser.find_or_create_by!(lesson: @lesson, user: current_user)
      add_lesson_xp
    else
      @daily_xp = 0
      @total_xp = 0
      @current_streak = 0
      @first_lesson_today = false
    end

    @course_path = course_path(@course.slug)
    
    # Find next lesson
    @next_lesson = @course.lessons.where("lessons.order > ?", @lesson.order).order(:order).first
    
    @continue_path = @next_lesson.present? ? course_lesson_path(@course, @next_lesson) : @course_path
  end
end
