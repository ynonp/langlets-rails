require "net/http"
require "json"

class ImportCourseJob < ApplicationJob
  queue_as :default

  def perform(create_song_progress_id, user_id, playlist_id = nil)
    progress = CreateSongProgress.find(create_song_progress_id)
    user = User.find(user_id)
    playlist = playlist_id ? Playlist.find_by(id: playlist_id) : nil

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

    if playlist
      add_to_playlist(course, playlist)
      Rails.logger.info "Added course #{course.id} to playlist #{playlist.id}"
    end

    CourseMailer.creation_complete(course).deliver_now

    Rails.logger.info "ImportCourseJob completed for course #{course.id}"

  rescue => e
    if course&.persisted?
      course.error!
      CourseMailer.creation_failed(course, e).deliver_now
    end
    Rails.logger.error "ImportCourseJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def add_to_playlist(course, playlist)
    existing_assoc = CoursesPlaylist.find_by(course: course)

    if existing_assoc
      existing_assoc.update!(playlist: playlist)
    else
      max_order = playlist.courses_playlists.maximum(:order) || 0
      CoursesPlaylist.create!(
        course: course,
        playlist: playlist,
        order: max_order + 1
      )
    end
  end

  def generate_slug_with_video_id(title, video_id)
    Courses::Naming.call(title: title, video_id: video_id).slug
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
    Youtube::Url.video_id(url)
  end

  # Best-effort by design: this job runs after the work has been committed to, so
  # a weak title beats a failed import.
  def fetch_video_title(_video_id, fallback_url)
    Youtube::Oembed.fetch_title(fallback_url)
  end
end
