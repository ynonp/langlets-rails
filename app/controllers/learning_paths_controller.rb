class LearningPathsController < ApplicationController
  before_action :set_learning_path, only: [:show, :search_courses]
  
  def show
    @tags = Tag.used_in_learning_path(@learning_path)
    @courses = get_filtered_courses
    @page = [params[:page].to_i, 1].max # Ensure page is at least 1
    @per_page = 12
    
    # Convert to array and precompute lesson counts to avoid N+1 queries
    courses_array = @courses.limit(@per_page).offset((@page - 1) * @per_page).to_a
    lesson_counts = precompute_lesson_counts(courses_array)
    
    if user_signed_in?
      # Get progress data for courses in one efficient query
      progress_data = calculate_progress_for_courses(courses_array, current_user)
      
      # Assign progress data and lesson counts to course objects
      @courses = courses_array.map do |course|
        course.define_singleton_method(:user_progress) { progress_data[course.id] || 0 }
        course.define_singleton_method(:has_progress?) { (progress_data[course.id] || 0) > 0 }
        course.define_singleton_method(:cached_lesson_count) { lesson_counts[course.id] || 0 }
        course
      end
    else
      @courses = courses_array.map do |course|
        course.define_singleton_method(:user_progress) { 0 }
        course.define_singleton_method(:has_progress?) { false }
        course.define_singleton_method(:cached_lesson_count) { lesson_counts[course.id] || 0 }
        course
      end
    end
    
    @has_more = @courses.size == @per_page
  end
  
  def search_courses
    @courses = get_filtered_courses
    @page = [params[:page].to_i, 1].max # Ensure page is at least 1
    @per_page = 12
    
    # Get paginated courses
    courses_array = @courses.limit(@per_page).offset((@page - 1) * @per_page).to_a
    lesson_counts = precompute_lesson_counts(courses_array)
    
    if user_signed_in?
      progress_data = calculate_progress_for_courses(courses_array, current_user)
      
      @courses = courses_array.map do |course|
        course.define_singleton_method(:user_progress) { progress_data[course.id] || 0 }
        course.define_singleton_method(:has_progress?) { (progress_data[course.id] || 0) > 0 }
        course.define_singleton_method(:cached_lesson_count) { lesson_counts[course.id] || 0 }
        course
      end
    else
      @courses = courses_array.map do |course|
        course.define_singleton_method(:user_progress) { 0 }
        course.define_singleton_method(:has_progress?) { false }
        course.define_singleton_method(:cached_lesson_count) { lesson_counts[course.id] || 0 }
        course
      end
    end
    
    @has_more = @courses.size == @per_page
    
    render json: {
      courses: render_to_string(partial: 'courses', locals: { courses: @courses }, formats: [:html]),
      has_more: @has_more,
      page: @page
    }
  end
  
  private
  
  def set_learning_path
    @learning_path = LearningPath.find(params[:id])
  end
  
  def get_filtered_courses
    courses = @learning_path.courses.published.includes(:language, :lessons, :tags)

    if params[:lang].present?
      language = Language.find_by(iso_name: params[:lang])
      courses = courses.where(language: language) if language
    end
    
    # Filter by tag if specified
    if params[:tag].present? && params[:tag] != 'all'
      courses = courses.joins(:tags).where(tags: { name: params[:tag] })
    end
    
    # Filter by search query if specified
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      courses = courses.where("LOWER(courses.name) LIKE ?", search_term)
    end
    
    courses.order(created_at: :desc)
  end
  
  def precompute_lesson_counts(courses)
    return {} if courses.empty?
    
    lesson_counts = {}
    courses.each do |course|
      lesson_counts[course.id] = course.lessons.size
    end
    lesson_counts
  end
  
  def calculate_progress_for_courses(courses, user)
    return {} unless user && courses.any?
    
    course_ids = courses.map(&:id)
    
    # Get lesson counts for all courses in one query
    lesson_counts = Course.joins(:lessons)
                         .where(id: course_ids)
                         .group('courses.id')
                         .count('lessons.id')
    
    # Get completed lesson counts for all courses in one query
    completed_counts = Course.joins(lessons: :lesson_users)
                            .where(id: course_ids, lesson_users: { user: user })
                            .group('courses.id')
                            .count('lessons.id')
    
    # Calculate progress for each course
    progress_data = {}
    courses.each do |course|
      total = lesson_counts[course.id] || 0
      completed = completed_counts[course.id] || 0
      progress_data[course.id] = total > 0 ? ((completed.to_f / total) * 100).round : 0
    end
    
    progress_data
  end
end