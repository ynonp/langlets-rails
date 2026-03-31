class Course < ApplicationRecord
  belongs_to :user
  has_many :lessons, -> { order(order: :asc) }, dependent: :destroy
  belongs_to :language, optional: true

  has_many :courses_learning_paths, dependent: :destroy
  has_many :learning_paths, through: :courses_learning_paths

  has_many :course_tags, dependent: :destroy
  has_many :tags, through: :course_tags

  # Status enum
  enum :status, {
    pending: 0,
    published: 1,
    processing: 2,
    error: 3
  }

  validates :slug, presence: true
  validates :name, presence: true, uniqueness: true
  validates :main_media_url, presence: true
  validate :slug_uniqueness_with_user_check

  # Scopes
  scope :published_courses, -> { where(status: :published) }
  scope :processing_courses, -> { where(status: :processing) }
  scope :with_full_player, -> { where(show_full_course_player: true) }
  scope :not_in_learning_paths, -> {
    where.not(
      id: LearningPath
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

  def create_short!(data_hash)
    raise "Missing creation data" unless data_hash["lessons"]
    raise "Missing YouTube URL" unless data_hash["youtubeurl"]
    raise "Missing clip language" unless data_hash["clip_language"]
    raise "Missing translation language" unless data_hash["translation_language"]

    l1 = Language.find_by(english_name: data_hash["clip_language"])
    l2 = Language.find_by(english_name: data_hash["translation_language"])
    medium = Medium.find_or_create_by!(url: data_hash["youtubeurl"])

    self.lessons.destroy_all
    medium.phrases.destroy_all

    data_hash["lessons"].each_with_index do |lesson_data, lesson_index|
      lesson_slug = unique_lesson_slug(lesson_data["title"].parameterize)

      l = Lesson.create!(
        medium: medium,
        slug: lesson_slug,
        course: self,
        order: lesson_index,
        name: lesson_data["title"],
        user: self.user)

      a1 = Activities::WatchVideoActivity.create!(lesson: l, order: 1, user: self.user)
      a2 = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2, user: self.user)
      a3 = Activities::WordOrderActivity.create!(lesson: l, order: 4, user: self.user)
      a5 = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 5, user: self.user)
      a8 = Activities::MatchTokensActivity.create!(lesson: l, order: 3, user: self.user)

      phrases = lesson_data["phrases"].each_with_index.map do |phrase_data, phrase_index|
        p = Phrase.create!(
          text_l1: phrase_data["text_l1"],
          text_l2: phrase_data["text_l2"],
          timestamp: phrase_data["timestamp"],
          medium:,
          l1:,
          l2:,
        )

        a5.phrases << p
        (phrase_data["translations"] || []).each do |token_translation_data|
          # Validate indices before attempting DB creation
          l1_start = token_translation_data["l1_index"].first
          l1_end = token_translation_data["l1_index"].last
          l2_start = token_translation_data["l2_index"]&.first
          l2_end = token_translation_data["l2_index"]&.last

          if l1_start > l1_end
            Rails.logger.error("Invalid L1 indices for phrase #{p.id}: l1_start=#{l1_start} >= l1_end=#{l1_end}. Skipping this token translation.")
            next
          end

          if l2_start > l2_end
            Rails.logger.error("Invalid L2 indices for phrase #{p.id}: l2_start=#{l2_start} >= l2_end=#{l2_end}. Skipping this token translation.")
            next
          end

          begin
            t = TokenTranslation.create!(
              phrase: p,
              l1_start_index: l1_start,
              l2_start_index: l2_start,
              l1_end_index: l1_end,
              l2_end_index: l2_end,
              similar_sound: token_translation_data["similar_sound"],
              translation: token_translation_data["translation"],
            )

            # a7.token_translations << t if token_translation_data["listening_activity"] == 1
            a5.token_translations << t if token_translation_data["language_alignment_activity"] == 1
          rescue ActiveRecord::RecordNotUnique => e
            Rails.logger.error("Duplicate token translation for phrase #{p.id}: l1_start=#{l1_start}, l1_end=#{l1_end}. Skipping duplicate. Error: #{e.message}")
          end
        end

        p
      end
      a1.phrases = phrases
      a2.phrases = phrases.sample(4)
      a3.phrases = phrases.sample(4)
      a8.token_translations = a1.phrases.flat_map(&:token_translations).sample(15)
    end

    medium.reload
    finish_lesson_slug = unique_lesson_slug("final-review")

    finish_lesson = Lesson.create!(
      medium: medium,
      slug: finish_lesson_slug,
      course: self,
      order: self.lessons.count,
      name: "Final Review",
      user: self.user
      )
    a1 = Activities::WatchVideoActivity.create!(lesson: finish_lesson, order: 1, user: self.user)
    a2 = Activities::MatchTokensActivity.create!(lesson: finish_lesson, order: 2, user: self.user)
    a3 = Activities::LanguageAlignmentActivity.create!(lesson: finish_lesson, order: 3, user: self.user)

    a1.phrases = medium.phrases.ordered_by_timestamp
    a2.token_translations = medium.phrases.flat_map(&:token_translations).sample(50)
    a3.phrases = medium.phrases.ordered_by_timestamp
    a3.token_translations = medium.phrases.flat_map(&:token_translations).sample(50)
  end

  def create_song!(data_hash)
    raise "Missing creation data" unless data_hash["lessons"]
    raise "Missing YouTube URL" unless data_hash["youtubeurl"]
    raise "Missing clip language" unless data_hash["clip_language"]
    raise "Missing translation language" unless data_hash["translation_language"]
    raise "Slug is required" if slug.nil?

    Rails.logger.info("Finding languages")
    l1 = Language.find_by(english_name: data_hash["clip_language"])
    l2 = Language.find_by(english_name: data_hash["translation_language"])
    Rails.logger.info("Finding medium")
    medium = Medium.find_or_create_by!(url: data_hash["youtubeurl"], language: l1)

    all_alignment_tokens = []
    all_listen_tokens = []

    Rails.logger.info("Deleting previous lessons")
    self.lessons.destroy_all
    medium.phrases.destroy_all

    Rails.logger.info("Creating new lessons")
    data_hash["lessons"].each_with_index do |lesson_data, lesson_index|
      Rails.logger.info("Creating lesson: #{lesson_data["title"]}")
      lesson_slug = unique_lesson_slug(lesson_data["title"].parameterize)

      l = Lesson.create!(
        medium: medium,
        slug: lesson_slug,
        course: self,
        order: lesson_index,
        name: lesson_data["title"],
        user: self.user)

      a1 = Activities::WatchVideoActivity.create!(lesson: l, order: 1, user: self.user)

      a2 = if rand() > -1
        Activities::MatchPhrasesActivity.create!(lesson: l, order: 2, user: self.user)
      else
        Activities::WordOrderActivity.create!(lesson: l, order: 2, user: self.user)
      end
      a3 = Activities::MatchTokensActivity.create!(lesson: l, order: 3, user: self.user)
      a4 = Activities::SortPhrasesActivity.create!(lesson: l, order: 4, user: self.user)
      a5 = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 5, user: self.user)
      a6 = Activities::SpeakActivity.create!(lesson: l, order: 6, user: self.user)
      a7 = Activities::ListenActivity.create!(lesson: l, order: 7, user: self.user)

      phrases = lesson_data["phrases"].each_with_index.map do |phrase_data, phrase_index|
        p = Phrase.create!(
          text_l1: phrase_data["text_l1"],
          text_l2: phrase_data["text_l2"],
          timestamp: phrase_data["timestamp"],
          medium:,
          l1:,
          l2:,
        )


        (phrase_data["translations"] || []).each do |token_translation_data|
          # Validate indices before attempting DB creation
          l1_start = token_translation_data["l1_index"].first
          l1_end = token_translation_data["l1_index"].last
          l2_start = token_translation_data["l2_index"]&.first
          l2_end = token_translation_data["l2_index"]&.last

          if l1_start > l1_end
            Rails.logger.error("Invalid L1 indices for phrase #{p.id}: l1_start=#{l1_start} >= l1_end=#{l1_end}. Skipping this token translation.")
            next
          end

          if l2_start > l2_end
            Rails.logger.error("Invalid L2 indices for phrase #{p.id}: l2_start=#{l2_start} >= l2_end=#{l2_end}. Skipping this token translation.")
            next
          end

          begin
            t = TokenTranslation.create!(
              phrase: p,
              l1_start_index: l1_start,
              l2_start_index: l2_start,
              l1_end_index: l1_end,
              l2_end_index: l2_end,
              similar_sound: token_translation_data["similar_sound"],
              translation: token_translation_data["translation"],
            )

            if token_translation_data["listening_activity"] == 1
              a7.token_translations << t
              all_listen_tokens << t
            end

            if token_translation_data["language_alignment_activity"] == 1
              a5.token_translations << t
              all_alignment_tokens << t
            end
          rescue ActiveRecord::RecordNotUnique => e
            Rails.logger.error("Duplicate token translation for phrase #{p.id}: l1_start=#{l1_start}, l1_end=#{l1_end}. Skipping duplicate. Error: #{e.message}")
          end
        end

        p
      end
      a1.phrases = phrases
      a2.phrases = phrases
      a3.token_translations = phrases.flat_map(&:token_translations).sample(15)
      a4.phrases = phrases.sample(5)
      a5.phrases = phrases
      a6.phrases = phrases
      a7.phrases = phrases
    end

    medium.reload
    finish_lesson_slug = unique_lesson_slug("song-review")

    finish_lesson = Lesson.create!(
      medium: medium,
      slug: finish_lesson_slug,
      course: self,
      order: self.lessons.count,
      name: "Song Review",
      user: self.user
      )
    a1 = Activities::WatchVideoActivity.create!(lesson: finish_lesson, order: 1, user: self.user)
    a2 = Activities::MatchTokensActivity.create!(lesson: finish_lesson, order: 2, user: self.user)
    a3 = Activities::LanguageAlignmentActivity.create!(lesson: finish_lesson, order: 3, user: self.user)
    a4 = Activities::ListenActivity.create!(lesson: finish_lesson, order: 4, user: self.user)

    a1.phrases = medium.phrases.ordered_by_timestamp
    a2.token_translations = medium.phrases.flat_map(&:token_translations).sample(50)

    a3.phrases = medium.phrases.ordered_by_timestamp
    a3.token_translations = all_alignment_tokens

    a4.phrases = medium.phrases.ordered_by_timestamp
    a4.token_translations = all_listen_tokens
  end

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
