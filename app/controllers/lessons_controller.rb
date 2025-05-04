class LessonsController < ApplicationController
  def show
    @lesson = Lesson.find_by(slug: params[:id])
    @activity = @lesson.activities.find_by(order: params[:a]) || @lesson.activities.first

    current_order = params[:a].to_i
    next_order = current_order.positive? ? current_order + 1 : 2

    @next_activity_path = lesson_path(@lesson.slug, a: next_order)
  end
end
