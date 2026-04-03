require "net/http"
require "json"

class ImportCourseJob < ApplicationJob
  queue_as :default

  def perform(create_song_progress_id, user_id, learning_path_id = nil)
    progress = CreateSongProgress.find(create_song_progress_id)
    user = User.find(user_id)
    learning_path = learning_path_id ? LearningPath.find_by(id: learning_path_id) : nil

    video_id = extract_video_id(progress.youtubeurl)
    title = fetch_video_title(video_id, progress.youtubeurl)

    language = Language.find_by(english_name: progress.clip_language)

    existing_course = Course.find_by(
      main_media_url: progress.youtubeurl,
      user: user
    )

    if existing_course
      course = existing_course
      course.assign_attributes(
        name: title,
        language: language,
        status: :processing
      )
      course.lessons.destroy_all
      course.save!
    else
      slug = generate_slug_with_video_id(title, video_id)
      course = create_course_with_unique_slug(user: user, name: title, slug: slug, main_media_url: progress.youtubeurl, language: language)
    end

    Rails.logger.info "Starting ImportCourseJob for #{progress.youtubeurl}"

    CourseBuilder::BuildSong.new(progress, course).call

    course.published!

    if learning_path
      add_to_learning_path(course, learning_path)
      Rails.logger.info "Added course #{course.id} to learning path #{learning_path.id}"
    end

    CourseMailer.creation_complete(course).deliver_now

    Rails.logger.info "ImportCourseJob completed for course #{course.id}"

  rescue => e
    if course&.persisted?
      course.error!
      CourseMailer.creation_failed(course, e.message).deliver_now
    end
    Rails.logger.error "ImportCourseJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def add_to_learning_path(course, learning_path)
    existing_assoc = CoursesLearningPath.find_by(course: course)

    if existing_assoc
      existing_assoc.update!(learning_path: learning_path)
    else
      max_order = learning_path.courses_learning_paths.maximum(:order) || 0
      CoursesLearningPath.create!(
        course: course,
        learning_path: learning_path,
        order: max_order + 1
      )
    end
  end

  def generate_slug_with_video_id(title, video_id)
    base_slug = generate_slug(title)

    # If slug is too short (e.g., Arabic/Hebrew titles stripped), use video ID
    if base_slug.length < 3 && video_id
      base_slug = video_id.downcase
    end

    # Append video ID for guaranteed uniqueness
    video_id ? "#{base_slug}-#{video_id.downcase}" : base_slug
  end

  def create_course_with_unique_slug(user:, name:, slug:, main_media_url:, language:, max_retries: 10)
    retries = 0
    begin
      course = Course.new(
        name: name,
        slug: slug,
        main_media_url: main_media_url,
        language: language,
        user: user,
        status: :processing
      )

      course.save!
      course

    rescue ActiveRecord::RecordNotUnique => e
      retries += 1
      if retries < max_retries
        Rails.logger.warn "Slug collision for '#{slug}', adding suffix (attempt #{retries})..."
        slug = "#{slug}-#{retries}"
        retry
      else
        raise
      end
    end
  end

  def extract_video_id(url)
    match = url.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|shorts\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/)
    match ? match[1] : nil
  end

  def fetch_video_title(video_id, fallback_url)
    return "Untitled Course" unless video_id

    oembed_url = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=#{video_id}&format=json"

    uri = URI(oembed_url)
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      data["title"] || "Untitled Course"
    else
      Rails.logger.warn "Failed to fetch video title for #{video_id}: #{response.code}"
      video_id
    end
  rescue => e
    Rails.logger.warn "Failed to fetch video title for #{video_id}: #{e.message}"
    video_id
  end

  def generate_slug(title)
    title.slug_for_language
  end
end
