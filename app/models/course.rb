class Course < ApplicationRecord
  include FriendlyName # to_param -> slug, so course URLs use the slug not the id

  belongs_to :user
  belongs_to :create_song_progress, optional: true
  has_many :lessons, -> { order(order: :asc) }, dependent: :destroy

  # `language` is the language spoken in the video. Localized names and
  # readiness live in course_translations.
  belongs_to :language, optional: true
  has_many :course_translations, dependent: :destroy, inverse_of: :course
  has_one :localized_translation,
          -> { where(language_id: Current.translation_language_id) },
          class_name: "CourseTranslation"

  has_many :courses_playlists, dependent: :destroy
  has_many :playlists, through: :courses_playlists

  has_many :course_tags, dependent: :destroy
  has_many :tags, through: :course_tags

  has_many :enrollments, dependent: :destroy
  has_many :enrolled_users, through: :enrollments, source: :user

  # Status enum
  enum :status, {
    pending: 0,
    published: 1,
    processing: 2,
    error: 3
  }

  validates :slug, presence: true
  # Not unique: slug is the identifier (see FriendlyName), and two users can
  # legitimately import different videos that share a title.
  validates :name, presence: true
  validates :main_media_url, presence: true
  validate :slug_uniqueness_with_user_check

  # Scopes
  scope :published_courses, -> { where(status: :published) }
  scope :processing_courses, -> { where(status: :processing) }
  scope :with_full_player, -> { where(show_full_course_player: true) }
  # Courses with a ready translation in the given language; courses that predate
  # translations (no course_translations rows at all) show everywhere. EXISTS
  # rather than a left join so the scope composes with other joins and grouped
  # COUNTs without duplicating rows.
  scope :ready_in, ->(language) {
    language ||= Language.find_by(english_name: "English")
    where(
      "EXISTS (SELECT 1 FROM course_translations ready_translations " \
      "WHERE ready_translations.course_id = courses.id " \
      "AND ready_translations.language_id = ? AND ready_translations.status = ?) OR " \
      "NOT EXISTS (SELECT 1 FROM course_translations all_translations WHERE all_translations.course_id = courses.id)",
      language&.id,
      CourseTranslation.statuses[:ready]
    )
  }

  def translation_language = localized_translation&.language || Current.translation_language
  def localized_name = localized_translation&.name || name

  # Which video provider this course came from, derived from the stored URL —
  # no column, so existing rows answer correctly without a backfill.
  def provider = VideoSource.provider(main_media_url) || VideoSource::DEFAULT_PROVIDER
  def tiktok? = provider == :tiktok

  # youtube_video_id is the dedupe key (idx_courses_published_video_language) and
  # holds whichever provider's id. The fallback covers legacy rows imported
  # before the column existed.
  def video_id
    youtube_video_id.presence || VideoSource.video_id(main_media_url)
  end

  # Reads the column first, then derives. Deliberately in that order: YouTube
  # covers derive from main_media_url for free, so the ~all existing rows with a
  # NULL column keep rendering with no backfill, while TikTok — whose covers are
  # signed CDN URLs that can't be derived — gets the value oEmbed handed us at
  # import time.
  def thumbnail_url(quality = "hqdefault")
    self[:thumbnail_url].presence || VideoSource.derived_thumbnail_url(main_media_url, quality)
  end
  def translation_ready?(language = Current.translation_language)
    language && course_translations.ready.exists?(language_id: language.id)
  end

  # Only system playlists count here: a course tucked into someone's personal
  # playlist should still show up in the public "all courses" grid.
  scope :not_in_playlists, -> {
    where.not(
      id: Playlist
      .system_playlists
      .published
      .joins(:courses)
      .select("courses.id")
    )
  }

  # Scope to get courses with progress for a user
  scope :with_progress_for_user, ->(user) {
    joins(lessons: :lesson_users)
      .where(lesson_users: { user_id: user.id })
      .includes(:language)
      .select("courses.*, MAX(lesson_users.created_at) as latest_progress")
      .group("courses.id")
      .order("latest_progress DESC")
      .distinct
  }

  # Atomically claim and process the course
  # Returns true if successfully claimed and processed, false if already claimed/processed
  def process
    # Atomically try to claim the work - only one job will succeed
    updated = Course.where(
      id: id,
      status: [ :pending ]  # Only claim if status is pending
    ).update_all(
      status: :processing,
      updated_at: Time.zone.now
    )

    if updated == 0
      # Another job already claimed it or it's already completed
      return false
    end

    # We successfully claimed it, now do the work
    yield(reload) if block_given?
    true
  end

  # Calculate user progress for this course
  def progress_for_user(user)
    return 0 unless user

    # Always use fresh data to avoid stale cache issues
    total_lessons = lessons.count
    return 0 if total_lessons == 0

    completed_lessons = lessons.joins(:lesson_users).where(lesson_users: { user: user }).count
    ((completed_lessons.to_f / total_lessons) * 100).round
  end

  # First lesson without a completion record for the given user.
  # Returns the lesson id, or nil if all are completed / user is nil.
  def first_incomplete_lesson_id_for(user)
    return nil unless user

    completed = LessonUser.where(user: user).select(:lesson_id)
    lessons.where.not(id: completed).order(:order).limit(1).pick(:id)
  end

  # Get the medium for this course
  # All lessons in a course share the same medium
  def medium
    lessons.first&.medium
  end

  def unique_lesson_slug(base_slug)
    slug = base_slug
    counter = 1
    while self.lessons.exists?(slug: slug)
      slug = "#{base_slug}-#{counter}"
      counter += 1
    end
    slug
  end

  def sync_lesson_timestamps
    ordered_lessons = lessons.includes(activities: { activity_phrases: :phrase }).sort_by(&:order)

    # Precompute sorted unique phrases per lesson to avoid N+1 inside the loop
    lesson_phrases_map = ordered_lessons.to_h do |lesson|
      phrases = lesson.activities.flat_map { |a| a.activity_phrases.map(&:phrase) }.uniq.sort_by(&:timestamp)
      [lesson, phrases]
    end

    ordered_lessons.each_with_index do |lesson, index|
      lesson_phrases = lesson_phrases_map[lesson]
      next if lesson_phrases.empty?

      start_ts = lesson_phrases.first.timestamp

      end_ts = if (next_lesson = ordered_lessons[index + 1])
        next_phrases = lesson_phrases_map[next_lesson]
        next_phrases.any? ? next_phrases.first.timestamp : lesson_phrases.last.timestamp
      else
        Phrase.to_string_timestamp(lesson_phrases.last.timestamp_seconds + 5)
      end

      lesson.update!(start_timestamp: start_ts, end_timestamp: end_ts)
    end
  end

  private

  def slug_uniqueness_with_user_check
    return if slug.blank?

    existing_course = Course.find_by(slug: slug)
    return unless existing_course

    # If it's the same record (updating), allow it
    return if existing_course.id == id

    # If slug exists and belongs to a different user, reject
    if existing_course.user_id != user_id
      errors.add(:slug, "has already been taken")
      return
    end

    # If slug exists and belongs to the same user but is NOT in error status, reject
    unless existing_course.error?
      errors.add(:slug, "has already been taken")
    end

    # If slug exists and belongs to the same user and IS in error status, allow
    # (controller will handle reusing the course)
  end
end
