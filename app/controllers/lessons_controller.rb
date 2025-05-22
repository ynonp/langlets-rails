class LessonsController < ApplicationController
  def show
    @lesson = Lesson.find_by(slug: params[:id])
    @activity = @lesson.activities.find_by(order: params[:a]) || @lesson.activities.first

    current_order = params[:a].to_i
    next_order = current_order.positive? ? current_order + 1 : 2
    next_activity = @lesson.activities.find_by("activities.order >= ?", next_order)
    @course = CourseLesson.where(lesson: @lesson).first&.course
    @course_path = @course.present? ? course_path(@course.slug) : nil
    
    @next_activity_path = if next_activity.present?
      lesson_path(@lesson.slug, a: next_activity.order)
    else
      @course_path
    end
  end
end
