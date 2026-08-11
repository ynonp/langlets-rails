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
  has_many :channel_items, dependent: :destroy
  has_many :channels, through: :channel_items

  # Reading a Course — the course page, its lessons, its activities, the full
  # player — is governed by Channel visibility. Public and system Channels make
  # a Course readable by the world; listing is narrower because public is
  # link-only while system is globally discoverable. Everything else needs
  # ownership, an accepted subscription, or admin.
  def readable_by?(user)
    # Admins moderate everything, including a Course in no Channel at all.
    return true if user&.admin?

    ChannelContentQuery.courses_visible_to(user).where(id: id).exists?
  end

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

  # Operator utility for repairing courses whose token audio jobs were missed.
  # Only tokens without an attachment are enqueued, and the return value makes
  # the amount of work visible in the Rails console.
  def enqueue_missing_token_audio!
    return 0 unless medium

    tokens = PhraseToken
      .joins(:phrase)
      .where(phrases: { medium_id: medium.id })
      .missing_l1_audio

    enqueued_count = 0
    tokens.find_each do |token|
      GenerateTokenAudioJob.perform_later(token.id)
      enqueued_count += 1
    end

    enqueued_count
  end

  def correct_text(old_text, new_text, tokens: [], translations:)
    token_specs = normalize_correction_token_specs(tokens)
    translation_specs = normalize_correction_translations(translations)
    phrases = medium&.phrases&.where(text_l1: old_text)&.ordered_by_timestamp&.to_a || []
    raise ArgumentError, "no phrase has the complete text #{old_text.inspect}" if phrases.empty?

    transaction do
      all_affected_activities = Hash.new(0)

      phrases.each do |phrase|
        affected_activities = phrase.correct_text(old_text, new_text)
        created_tokens = token_specs.map { |text, token_translations| phrase.create_token(text, token_translations) }

        translation_specs.each do |language, text|
          phrase.phrase_translations
            .find_or_initialize_by(language: language)
            .update!(text: text)
        end

        affected_activities.each do |activity, deleted_count|
          all_affected_activities[activity] += deleted_count
          next if created_tokens.empty?

          deleted_count.times do
            activity.activity_phrase_tokens.create!(phrase_token: created_tokens.sample)
          end
        end
      end

      if create_song_progress
        CreateSongProgressRebuilder
          .new(self, progress: create_song_progress)
          .call(force: true)
      end

      all_affected_activities
    end
  end

  # Rebuild an existing course from the beginning with the current import
  # pipeline. This is intentionally destructive and is meant for operator use
  # when upgrading old courses to a newer pipeline version.
  #
  # The old Course cannot be handed to ImportRequest#retry!: deleting it would
  # leave the request with no course, while retry! requires a pending course for
  # CreateCourseJob to claim. Preserve the course's identity fields in a fresh
  # shell, move its import requests to that shell, then let the normal retry
  # path start the import.
  #
  # A multi-language course gets one request per language it was built in
  # (see #regeneration_import_requests). Only the first one actually triggers
  # CreateCourseJob; ImportRequest#retry! finds the rest already covered by
  # that active sibling and leaves them queued, and Imports::Finalizer picks
  # them up as outstanding languages once the first publishes — the same
  # mechanism a normal multi-language import uses.
  #
  # By default the languages come from the course's own course_translations.
  # Pass `languages` to override that — e.g. a course with no translation
  # data yet, where the caller wants to kick off several languages at once —
  # in which case the existing course_translations (if any) are ignored.
  #
  # Returns the primary (first-language) ImportRequest, the one that actually
  # started the run.
  def regenerate!(languages = nil)
    progress = create_song_progress ||
               CreateSongProgress.find_by!(
                 youtubeurl: main_media_url,
                 clip_language: language&.english_name
               )
    import_requests = regeneration_import_requests(progress, languages)

    transaction do
      progress.update!(data: {})

      course_attributes = attributes.slice(
        "name", "slug", "main_media_url", "language_id", "user_id",
        "show_full_course_player", "create_song_progress_id",
        "youtube_video_id", "thumbnail_url"
      )
      media = lessons.where.not(medium_id: nil).distinct.map(&:medium).compact
      requests = ImportRequest.where(course_id: id)

      # The FK from import_requests prevents deletion until the requests are
      # detached. Reattach every historical request afterwards so queue/history
      # rows do not become orphaned merely because one owner regenerated it.
      requests.update_all(course_id: nil, updated_at: Time.zone.now)
      media.each(&:destroy!)
      destroy!

      replacement = Course.create!(course_attributes.merge("status" => :error))
      requests.update_all(course_id: replacement.id, updated_at: Time.zone.now)

      import_requests.each do |import_request|
        import_request.update!(
          course: replacement,
          create_song_progress: progress,
          status: :failed
        )
      end
      # Order matters: the first retry! finds no active sibling yet and starts
      # the run; every later one finds that request already active and rides
      # along instead of starting a second one (ImportRequest#covered_by_sibling?).
      import_requests.each(&:retry!)
    end

    import_requests.first
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
      [ lesson, phrases ]
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

  def normalize_correction_token_specs(tokens)
    specs = Array(tokens)
    specs = specs.each_slice(2).to_a if specs.all? { |item| !item.is_a?(Array) }

    unless specs.all? { |spec| spec.is_a?(Array) && spec.size == 2 && spec.first.is_a?(String) && spec.last.is_a?(Hash) }
      raise ArgumentError, "tokens must contain [text, translation_table] pairs"
    end
    specs
  end

  def normalize_correction_translations(translations)
    unless translations.is_a?(Hash) && translations.present? &&
        translations.none? { |language, text| language.blank? || text.blank? }
      raise ArgumentError, "translations must be a non-empty language-to-text hash"
    end

    translations.to_h do |iso_name, text|
      [ Language.find_by!(iso_name: iso_name.to_s), text ]
    end
  end

  # One request per language the course was built in, ordered to match
  # #regeneration_languages (earliest course_translations first). Reuses an
  # existing request for that user/course/language if one is already there,
  # the same way the single-language version used to.
  def regeneration_import_requests(progress, languages = nil)
    regeneration_languages(languages).map do |lang|
      ImportRequest.where(course_id: id, user_id: user_id, translation_language: lang.english_name)
                   .recent_first.first ||
        user.import_requests.create!(
          youtube_url: main_media_url,
          youtube_video_id: video_id,
          clip_language: progress.clip_language,
          translation_language: lang.english_name,
          title: name,
          course: self,
          create_song_progress: progress,
          status: :failed
        )
    end
  end

  # Explicit `languages` wins outright and skips course_translations entirely,
  # even if some exist — that's the point of passing it.
  def regeneration_languages(languages = nil)
    return Array(languages) if languages.present?

    derived = course_translations.order(:id).map(&:language)
    raise ArgumentError, "course #{id} has no course_translations to name a translation language" if derived.empty?

    derived
  end

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
