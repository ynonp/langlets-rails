class LessonsController < ApplicationController
  def show
    @lesson = Lesson.find_by(slug: params[:id])
    @activity = @lesson.activities.find_by(order: params[:a]) || @lesson.activities.first

    current_order = params[:a].to_i
    next_order = current_order.positive? ? current_order + 1 : 2
    next_activity = @lesson.activities.find_by("activities.order >= ?", next_order)
    @course_path = @lesson.course.present? ? course_path(@lesson.course.slug) : nil
    @next_lesson = if @lesson.course.present?
      @lesson.course.lessons.find_by("lessons.order >= ?", @lesson.order + 1)
    else
      nil
    end
    
    @next_activity_path = if next_activity.present?
      lesson_path(@lesson.slug, a: next_activity.order)
    elsif @next_lesson.present?
      lesson_path(@next_lesson.slug, a: 1)
    else
      @course_path
    end
  end
end
