class CoursesController < ApplicationController
  def index
    @recommended_courses = if user_signed_in?
      current_user.recommended_for_me.includes(:language)
    else
      Course.none
    end
    
    @continue_learning_courses = if user_signed_in?
      Course.with_progress_for_user(current_user)
    else
      Course.none
    end
    
    @learning_paths = LearningPath.published.includes(:courses)
    @all_courses = Course.includes(:language)
    
    # Filter by language if provided
    if params[:language].present? && params[:language] != 'all'
      language = Language.find_by(english_name: params[:language])
      @all_courses = @all_courses.where(language: language) if language
    end
    
    @languages = Language.joins(:courses).distinct.order(:english_name)
  end

  def show
    @course = Course.find_by(slug: params[:id]) || Course.find(params[:id])
    
    @lessons = @course.lessons
                     .includes(:activities, :lesson_users, activities: :activity_users)
                     .with_progress_data(current_user)
                     .order(:order)
  end
end
