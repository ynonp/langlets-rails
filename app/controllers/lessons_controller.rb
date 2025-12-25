class LessonsController < ApplicationController
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
    
    @next_activity_path = if next_activity.present?
      course_lesson_path(@course, @lesson, a: next_activity.order)
    else
      # After last activity, go to finish lesson page
      finish_course_lesson_path(@course, @lesson)
    end

    @is_last_activity = next_activity.blank?

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
      @daily_xp = ActivityLog.daily_xp_for_user(current_user)
      @total_xp = ActivityLog.total_xp_for_user(current_user)
      @current_streak = ActivityLog.current_streak_for_user(current_user)
      
      # Check if this is the first lesson completed today for streak calculation
      today = Time.zone.now.to_date
      last_lesson_today = ActivityLog.where(user: current_user)
                                   .where.not(lesson_id: nil)
                                   .where(created_at: today.beginning_of_day..today.end_of_day)
                                   .exists?
      @first_lesson_today = !last_lesson_today
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
