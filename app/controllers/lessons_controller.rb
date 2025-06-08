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
    elsif @next_lesson.present?
      lesson_path(@next_lesson.slug)
    else
      @course_path
    end
  end
end
