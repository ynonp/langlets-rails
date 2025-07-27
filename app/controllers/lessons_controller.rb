class LessonsController < ApplicationController
  def show
    @lesson = Lesson.find_by(slug: params[:id]) || Lesson.find_by(id: params[:id])
    
    unless @lesson
      redirect_to root_path, alert: "Lesson not found"
      return
    end
    
    # Handle script parameter
    @current_script_code = params[:script]
    @current_script = Script.find_by(code: @current_script_code) if @current_script_code
    
    # Preload lesson with medium and all lesson phrases
    @lesson = Lesson.includes(
      medium: {
        phrases: [
          :l1, :l2,
          { text_l1: { script_variants: :script } },
          { text_l2: { script_variants: :script } }
        ]
      }
    ).find(@lesson.id)
    
    # Optimized preloading for all activities and their dependencies
    @activities = @lesson.activities.order(order: :asc).includes(
      phrases: [
        :l1, :l2,  # Languages
        { text_l1: { script_variants: :script } },
        { text_l2: { script_variants: :script } },
        { token_translations: [
          { l1_audio_attachment: :blob },
          { phrase: [
            :l1, :l2,
            { text_l1: { script_variants: :script } },
            { text_l2: { script_variants: :script } }
          ]}
        ]}
      ],
      token_translations: [
        { l1_audio_attachment: :blob },
        { phrase: [
          :l1, :l2,
          { text_l1: { script_variants: :script } },
          { text_l2: { script_variants: :script } }
        ]}
      ]
    ).load
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
    
    # Preserve script parameter in navigation links
    script_param = @current_script_code ? { script: @current_script_code } : {}
    
    @next_activity_path = if next_activity.present?
      lesson_path(@lesson.slug, { a: next_activity.order }.merge(script_param))
    else
      # After last activity, go to finish lesson page
      finish_lesson_path(@lesson.slug, script_param)
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
