require "net/http"
require "json"

class ImportCourseJob < ApplicationJob
  queue_as :default

  def perform(create_song_progress_id, user_id, language_id, playlist_id = nil)
    progress = CreateSongProgress.find(create_song_progress_id)
    user = User.find(user_id)
    language = Language.find(language_id)
    playlist = playlist_id ? Playlist.find_by(id: playlist_id) : nil

    video = resolve_video(progress.youtubeurl)
    video_id = video&.video_id || extract_video_id(progress.youtubeurl)
    title = video&.title || VideoSource.video_id(progress.youtubeurl) || "Untitled Course"

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
        status: :processing,
        **cover_attributes(video)
      )
      course.lessons.destroy_all
      course.save!
    else
      slug = generate_slug_with_video_id(title, video_id)
      course = create_course_with_unique_slug(user: user, name: title, slug: slug, main_media_url: progress.youtubeurl, language: language, cover: cover_attributes(video))
    end

    Rails.logger.info "Starting ImportCourseJob for #{progress.youtubeurl}"

    CourseBuilder::BuildSong.new(progress, course).call(language)

    course.published!

    if playlist
      add_to_playlist(course, playlist)
      Rails.logger.info "Added course #{course.id} to playlist #{playlist.id}"
    end

    # The legacy rake path has no ImportRequest, so it notifies the creator
    # itself rather than through Imports::Settlement.
    Notifications.deliver(user: user, kind: :course_ready, course: course)

    Rails.logger.info "ImportCourseJob completed for course #{course.id}"

  rescue => e
    if course&.persisted?
      course.error!
      Notifications.deliver(user: user, kind: :course_failed, course: course, reason: e.message)
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

  def create_course_with_unique_slug(user:, name:, slug:, main_media_url:, language:, cover: {}, max_retries: 10)
    retries = 0
    begin
      course = Course.new(
        name: name,
        slug: slug,
        main_media_url: main_media_url,
        language: language,
        user: user,
        status: :processing,
        **cover
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
    VideoSource.video_id(url)
  end

  # Best-effort by design: this job runs after the pipeline has already done the
  # expensive work, so a weak title beats a failed import. One oEmbed call now
  # serves the title *and* the cover — it used to fetch the same response and
  # throw everything but the title away.
  def resolve_video(url)
    VideoSource.fetch(url)
  rescue VideoSource::UnavailableVideo, StandardError => e
    Rails.logger.warn "oEmbed lookup failed for #{url.inspect}: #{e.message}"
    nil
  end

  # Only stored when it can't be derived from the URL later. YouTube covers
  # derive for free, so those stay NULL — and a failed oEmbed must not blank an
  # existing cover, hence the empty hash rather than an explicit nil.
  def cover_attributes(video)
    return {} if video.nil? || video.youtube? || video.thumbnail_url.blank?

    { thumbnail_url: video.thumbnail_url }
  end
end
