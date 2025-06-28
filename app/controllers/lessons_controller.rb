class LessonsController < ApplicationController
  def show
    @lesson = Lesson.find_by(slug: params[:id]) || Lesson.find_by(id: params[:id])
    
    unless @lesson
      redirect_to root_path, alert: "Lesson not found"
      return
    end
    
    @activities = @lesson.activities.order(order: :asc).load
    @activity = @activities.find_by(order: params[:a]) || @activities.first
    @current_url = lesson_path(a: @activity.order)
    @videoid = @lesson.medium.extract_youtube_video_id

    current_order = params[:a].to_i
    
    next_activity = @lesson.activities.where("activities.order > ?", @activity.order).order(order: :asc).first
    @course_path = @lesson.course.present? ? course_path(@lesson.course.slug) : nil
    @next_lesson = if @lesson.course.present?
      @lesson.course.lessons.find_by("lessons.order >= ?", @lesson.order + 1)
    else
      nil
    end
    
    @next_activity_path = if next_activity.present?
      lesson_path(@lesson.slug, a: next_activity.order)
    else
      # After last activity, go to finish lesson page
      finish_lesson_path(@lesson.slug)
    end

    # Prepare progress data for completion messages
    @progress_data = {
      activity_id: @activity.id,
      lesson_id: (@activity.is_last_in_lesson? ? @lesson.id : nil),
      activity_xp: @activity.xp_value
    }.compact
  end

  def finish
    @lesson = Lesson.find_by(slug: params[:id]) || Lesson.find_by(id: params[:id])
    
    unless @lesson
      redirect_to root_path, alert: "Lesson not found"
      return
    end

    # Calculate XP earned in this lesson
    @lesson_xp = @lesson.activities.sum(&:xp_value)
    
    # Get user stats and handle streak (only for authenticated users)
    if current_user
      @user_stats = UserGameStat.for_user(current_user)
      
      # Check if this is the first lesson completed today for streak calculation
      today = Date.current
      @first_lesson_today = @user_stats.last_activity_date != today
      
      # Update streak if first lesson today
      if @first_lesson_today
        @user_stats.add_streak_if_first_lesson_today
      end
    else
      @user_stats = nil
      @first_lesson_today = false
    end

    @course_path = @lesson.course.present? ? course_path(@lesson.course.slug) : root_path
    
    # Find next lesson
    @next_lesson = if @lesson.course.present?
      @lesson.course.lessons.where("lessons.order > ?", @lesson.order).order(:order).first
    else
      nil
    end
    
    @continue_path = @next_lesson.present? ? lesson_path(@next_lesson.slug) : @course_path
  end
end
