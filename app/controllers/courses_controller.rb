class CoursesController < ApplicationController
  def index
    @learning_paths = LearningPath.published.includes(:courses)
    @languages = Language.joins(:courses).distinct.order(:english_name)
    
    # Get all courses with progress data in a single optimized query
    # For now, show all courses regardless of owner (later we may want to filter by user)
    @all_courses = Course.includes(:language, :lessons).order(created_at: :desc)
    
    # Filter by language if provided
    if params[:language].present? && params[:language] != 'all'
      language = Language.find_by(english_name: params[:language])
      @all_courses = @all_courses.where(language: language) if language
    end
    
    # Convert to array and precompute lesson counts to avoid N+1 queries
    all_courses_array = @all_courses.to_a
    lesson_counts = precompute_lesson_counts(all_courses_array)
    
    if user_signed_in?
      # Get progress data for all courses in one efficient query
      progress_data = calculate_progress_for_courses(all_courses_array, current_user)
      
      # Get the ordering for continue learning courses (courses with progress, ordered by latest activity)
      continue_learning_order = get_continue_learning_order(current_user)
      
      # Assign progress data and lesson counts to course objects
      @all_courses = all_courses_array.map do |course|
        course.define_singleton_method(:user_progress) { progress_data[course.id] || 0 }
        course.define_singleton_method(:has_progress?) { (progress_data[course.id] || 0) > 0 }
        course.define_singleton_method(:cached_lesson_count) { lesson_counts[course.id] || 0 }
        course
      end
      
      # Separate courses for different sections
      @recommended_courses = current_user.recommended_for_me.includes(:language).to_a.map do |course|
        course.define_singleton_method(:user_progress) { progress_data[course.id] || 0 }
        course.define_singleton_method(:has_progress?) { (progress_data[course.id] || 0) > 0 }
        course.define_singleton_method(:cached_lesson_count) { lesson_counts[course.id] || 0 }
        course
      end
      
      # Filter and sort continue learning courses
      @continue_learning_courses = @all_courses.select(&:has_progress?).sort_by do |course|
        continue_learning_order[course.id] || Float::INFINITY
      end
    else
      @recommended_courses = []
      @continue_learning_courses = []
      @all_courses = all_courses_array.map do |course|
        course.define_singleton_method(:user_progress) { 0 }
        course.define_singleton_method(:has_progress?) { false }
        course.define_singleton_method(:cached_lesson_count) { lesson_counts[course.id] || 0 }
        course
      end
    end
  end


  def show
    @course = Course.find_by(slug: params[:id]) || Course.find(params[:id])
    @lessons = @course.lessons
                     .includes(:activities, :lesson_users, activities: :activity_users)
                     .with_progress_data(current_user)
                     .order(:order)
  end

  private

  def precompute_lesson_counts(courses)
    return {} if courses.empty?
    
    # Since we already have lessons preloaded, we can count them in memory
    # This avoids additional database queries
    lesson_counts = {}
    courses.each do |course|
      lesson_counts[course.id] = course.lessons.size
    end
    lesson_counts
  end

  def get_continue_learning_order(user)
    # Get courses with progress ordered by latest activity (for continue learning section)
    # Returns a hash with course_id => order_index for efficient sorting
    course_order = {}
    Course.joins(lessons: :lesson_users)
          .where(lesson_users: { user_id: user.id })
          .select('courses.id, MAX(lesson_users.created_at) as latest_progress')
          .group('courses.id')
          .order('latest_progress DESC')
          .each_with_index do |course, index|
      course_order[course.id] = index
    end
    course_order
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
