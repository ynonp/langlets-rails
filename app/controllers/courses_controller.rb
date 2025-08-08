class CoursesController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create]

  def index
    @learning_paths = LearningPath.published.includes(:courses)
    @languages = Language.joins(:courses).distinct.order(:english_name)
    
    # Get all published courses with progress data in a single optimized query
    @all_courses = Course.published.includes(:language, :lessons).order(created_at: :desc)
    
    # Get user's processing courses if signed in
    @processing_courses = user_signed_in? ? current_user.courses.processing.includes(:language).order(created_at: :desc) : []
    
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

  def new
    authorize! :create, Course
    @course = Course.new
    @languages = Language.all.order(:english_name)
  end

  def create
    authorize! :create, Course
    @course = current_user.courses.build(course_params)

    # Create and validate the CreateSongProgress record upfront
    @create_song_progress = CreateSongProgress.find_or_initialize_by(
      youtubeurl: @course.main_media_url,
      clip_language: params[:clip_language],
      translation_language: params[:translation_language],
    ) do |p|
      p.lyrics = params[:lyrics]
      p.data = { lesson_template: params[:lesson_template] }
    end
    
    # Validate both course and progress record
    course_valid = @course.valid?
    progress_valid = @create_song_progress.valid?
    
    if course_valid && progress_valid
      @course.save!
      @create_song_progress.save!
      
      # Queue the background job with the validated records
      CreateCourseJob.perform_later(@create_song_progress.id, @course.id)
      
      redirect_to courses_path, notice: 'Your new course is being created! You\'ll receive an email when it\'s ready.'
    else
      # Merge validation errors from both models
      @create_song_progress.errors.each do |error|
        case error.attribute
        when :youtubeurl
          @course.errors.add(:main_media_url, error.message)
        when :clip_language
          @course.errors.add(:clip_language, error.message)
        when :translation_language
          @course.errors.add(:translation_language, error.message)
        end
      end
      
      @languages = Language.all.order(:english_name)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def course_params
    params
    .require(:course)
    .permit(:name, :slug, :main_media_url, :language_id, :hebrew_script_available)
  end

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
