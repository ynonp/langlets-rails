class CoursesController < ApplicationController
  def index
  end

  def show
    @course = Course.find_by(slug: params[:id]) || Course.find(params[:id])
    @lessons = @course.lessons
  end
end
