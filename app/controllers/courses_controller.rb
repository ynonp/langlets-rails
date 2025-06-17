class CoursesController < ApplicationController
  def index
  end

  def show
    @course = Course.find_by(slug: params[:id]) || Course.find(params[:id])
    
    @lessons = @course.lessons
                     .includes(:activities, :lesson_users, activities: :activity_users)
                     .with_progress_data(current_user)
                     .order(:order)
  end
end
