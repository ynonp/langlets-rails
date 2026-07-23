class CoursesController < ApplicationController
  before_action :authenticate_user!, only: [ :new, :create ]

  def index
    # The one place the web UI knows about the mobile app. Signed-in native users
    # land on the app's Home instead of this page; everyone on the web sees
    # exactly what they always have. Deciding this server-side (rather than
    # changing the app's start location) means it can be changed without an App
    # Store release.
    return redirect_to app_home_path if native_app? && user_signed_in?

    # Everyone sees the published system playlists; signed-in users also see
    # their own playlists. Only courses with a ready translation in the
    # subdomain's language are shown, and a playlist with none of those is
    # hidden entirely.
    visible_courses = Course.published.ready_in(Current.translation_language)
    @all_courses = Course.published.ready_in(Current.translation_language)
                         .includes(:language, :localized_translation)
                         .not_in_playlists.order(created_at: :desc)

    if current_language_code.present?
      language = Language.find_by(iso_name: current_language_code)
      if language
        visible_courses = visible_courses.where(language: language)
        @all_courses = @all_courses.where(language: language)
      end
    end

    # One grouped query decides which playlists survive and what clip count
    # their cards show, instead of a COUNT per playlist in the view.
    clip_counts = Playlist.visible_to(current_user)
                          .joins(:courses)
                          .merge(visible_courses)
                          .group("playlists.id")
                          .count
    @playlists = Playlist.where(id: clip_counts.keys)
                         .includes(courses: :language)
                         .order(:created_at)
                         .to_a
    @playlists.each do |playlist|
      count = clip_counts[playlist.id]
      playlist.define_singleton_method(:visible_clip_count) { count }
    end

    # Convert to array and precompute lesson counts to avoid N+1 queries
    @all_courses = @all_courses.left_joins(:lessons)
                  .select("courses.*, COUNT(lessons.id) AS lessons_count")
                  .group("courses.id")

    all_courses_array = @all_courses.to_a

    if user_signed_in?
      # Get progress data for all courses in one efficient query
      progress_data = calculate_progress_for_courses(all_courses_array, current_user)

      # Get the ordering for continue learning courses (courses with progress, ordered by latest activity)
      continue_learning_order = get_continue_learning_order(current_user)

      # Assign progress data and lesson counts to course objects
      @all_courses = all_courses_array.map do |course|
        course.define_singleton_method(:user_progress) { progress_data[course.id] || 0 }
        course.define_singleton_method(:has_progress?) { (progress_data[course.id] || 0) > 0 }
        course.define_singleton_method(:completed?) { (progress_data[course.id] || 0) >= 100 }
        course
      end

      # Separate courses for different sections
      @recommended_courses = current_user.recommended_for_me.includes(:language, :localized_translation).to_a.map do |course|
        course.define_singleton_method(:user_progress) { progress_data[course.id] || 0 }
        course.define_singleton_method(:has_progress?) { (progress_data[course.id] || 0) > 0 }
        course.define_singleton_method(:completed?) { (progress_data[course.id] || 0) >= 100 }
        course
      end

      # Build continue learning from ALL courses with progress (including learning path courses)
      continue_learning_ids = continue_learning_order.keys
      if continue_learning_ids.any?
        continue_courses = Course.published.ready_in(Current.translation_language)
                                 .includes(:language, :localized_translation)
                                 .where(id: continue_learning_ids)
        if current_language_code.present? && language
          continue_courses = continue_courses.where(language: language)
        end
        continue_courses = continue_courses.left_joins(:lessons)
                            .select("courses.*, COUNT(lessons.id) AS lessons_count")
                            .group("courses.id")
                            .to_a

        continue_progress = calculate_progress_for_courses(continue_courses, current_user)

        @continue_learning_courses = continue_courses.reject do |course|
          (continue_progress[course.id] || 0) >= 100
        end.map do |course|
          course.define_singleton_method(:user_progress) { continue_progress[course.id] || 0 }
          course.define_singleton_method(:has_progress?) { true }
          course.define_singleton_method(:completed?) { false }
          course
        end.sort_by do |course|
          continue_learning_order[course.id] || Float::INFINITY
        end
      else
        @continue_learning_courses = []
      end
    else
      @recommended_courses = []
      @continue_learning_courses = []
      @all_courses = all_courses_array.map do |course|
        course.define_singleton_method(:user_progress) { 0 }
        course.define_singleton_method(:has_progress?) { false }
        course.define_singleton_method(:completed?) { false }
        course
      end
    end
  end


  def show
    @course = Course.find_by(slug: params[:id]) || Course.find(params[:id])

    response.headers["Turbo-Visit"] = "reload"
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate"

    if current_user
      @daily_xp = ActivityLog.daily_xp_for_user(current_user)
      @streak_info = ActivityLog.streak_info_for_user(current_user)

      @lessons = @course.lessons
        .includes(:localized_translation, :activities, :lesson_users, activities: :activity_users)
        .with_progress_data(current_user)
        .order(:order)
      @all_done = @lessons.all?(&:completed?)
      @first_incomplete_lesson_id = @lessons.find { |l| l.in_progress? || l.not_started? }&.id
    else
      @lessons = @course.lessons.includes(:localized_translation)
      @all_done = false
      @first_incomplete_lesson_id = nil
      @daily_xp = 0
      @streak_info = { count: 0, completed_today: false, status: :no_streak }
    end
  end

  def new
    authorize! :create, Course
    @course = Course.new
    @languages = Language.all.order(:english_name)
  end

  def mark_done
    @course = Course.find_by(slug: params[:id]) || Course.find(params[:id])
    authenticate_user!

    @course.lessons.each do |lesson|
      LessonUser.find_or_create_by(lesson: lesson, user: current_user)
    end

    redirect_to course_path(@course.slug), notice: "Course marked as done!"
  end

  def reset_progress
    @course = Course.find_by(slug: params[:id]) || Course.find(params[:id])
    authenticate_user!

    lesson_ids = @course.lessons.select(:id)

    ApplicationRecord.transaction do
      ActivityUser.where(
        activity: Activity.where(lesson_id: lesson_ids),
        user: current_user
      ).destroy_all
      LessonUser.where(lesson_id: lesson_ids, user: current_user).destroy_all
    end

    redirect_to course_path(@course.slug), notice: "Progress reset. You can start fresh!"
  end

  def create
    authorize! :create, Course

    # Check if a course with this slug exists for the current user and is in error state
    existing_error_course = current_user.courses.find_by(slug: course_params[:slug], status: :error)

    if existing_error_course
      # Reuse the existing error course
      @course = existing_error_course
      @course.assign_attributes(course_params)
      @course.status = :pending
      # Clear existing lessons - they'll be regenerated by the job
      @course.lessons.destroy_all
    else
      # Build a new course
      @course = current_user.courses.build(course_params)
    end

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

      redirect_to courses_path, notice: "Your new course is being created! You'll receive an email when it's ready."
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
    .permit(:name, :slug, :main_media_url, :language_id)
  end

  def get_continue_learning_order(user)
    # Get courses with progress ordered by latest activity (for continue learning section)
    # Returns a hash with course_id => order_index for efficient sorting
    course_order = {}
    Course.joins(lessons: :lesson_users)
          .where(lesson_users: { user_id: user.id })
          .select("courses.id, MAX(lesson_users.created_at) as latest_progress")
          .group("courses.id")
          .order("latest_progress DESC")
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
                         .group("courses.id")
                         .count("lessons.id")

    # Get completed lesson counts for all courses in one query
    completed_counts = Course.joins(lessons: :lesson_users)
                            .where(id: course_ids, lesson_users: { user: user })
                            .group("courses.id")
                            .count("lessons.id")

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
