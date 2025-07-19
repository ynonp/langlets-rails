class Course < ApplicationRecord
  belongs_to :user
  has_many :lessons, -> { order(order: :asc) }, dependent: :destroy
  belongs_to :language, optional: true
  
  has_many :courses_learning_paths, dependent: :destroy
  has_many :learning_paths, through: :courses_learning_paths
  
  # Likes relationship
  has_many :course_likes, dependent: :destroy
  has_many :liked_by_users, through: :course_likes, source: :user

  # Status enum
  enum :status, {
    processing: 0,
    published: 1
  }

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true, uniqueness: true
  validates :main_media_url, presence: true

  # Scopes
  scope :published_courses, -> { where(status: :published) }
  scope :processing_courses, -> { where(status: :processing) }

  # Scope to get courses with progress for a user
  scope :with_progress_for_user, ->(user) {
    joins(lessons: :lesson_users)
      .where(lesson_users: { user_id: user.id })
      .includes(:language)
      .select('courses.*, MAX(lesson_users.created_at) as latest_progress')
      .group('courses.id')
      .order('latest_progress DESC')
      .distinct
  }

  # Like methods
  def liked_by?(user)
    return false unless user
    course_likes.exists?(user: user)
  end

  def likes_count
    course_likes.count
  end

  def create_short!(progress)
    raise "Missing creation data" unless progress.ready?
    data = progress.data

    l1 = Language.find_by(english_name: progress.clip_language)
    l2 = Language.find_by(english_name: progress.translation_language)
    medium = Medium.find_or_create_by!(url: progress.youtubeurl)

    self.lessons.destroy_all
    Lesson.where("slug like \'#{slug}%\'").destroy_all
    medium.phrases.destroy_all

    data["lessons"].each_with_index do |lesson_data, lesson_index|
      l = Lesson.create!(
        medium: medium,
        slug: "#{slug}#{lesson_index}",
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
          l1_start = token_translation_data["l1_start_index"]
          l1_end = token_translation_data["l1_end_index"] + 1
          l2_start = token_translation_data["l2_start_index"]
          l2_end = token_translation_data["l2_end_index"] + 1
          
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
    finish_lesson_slug = "#{self.slug}#{self.lessons.count}"
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

  def create_song!(progress)
    raise "Missing creation data" unless progress.ready?
    raise "Slug is required" if slug.nil?
    data = progress.data

    Rails.logger.info("Finding languages")
    l1 = Language.find_by(english_name: progress.clip_language)
    l2 = Language.find_by(english_name: progress.translation_language)
    Rails.logger.info("Finding medium")
    medium = Medium.find_or_create_by!(url: progress.youtubeurl)

    all_alignment_tokens = []
    all_listen_tokens = []

    Rails.logger.info("Deleting previous lessons")
    self.lessons.destroy_all
    Lesson.where("slug like \'#{slug}%\'").destroy_all
    medium.phrases.destroy_all

    Rails.logger.info("Creating new lessons")
    data["lessons"].each_with_index do |lesson_data, lesson_index|
      Rails.logger.info("Creating lesson: #{lesson_data["title"]}")
      l = Lesson.create!(
        medium: medium,
        slug: "#{slug}#{lesson_index}",
        course: self,
        order: lesson_index,
        name: lesson_data["title"],
        user: self.user)

      a1 = Activities::WatchVideoActivity.create!(lesson: l, order: 1, user: self.user)

      a2 = if rand() > 0.5
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
          l1_start = token_translation_data["l1_start_index"]
          l1_end = token_translation_data["l1_end_index"] + 1
          l2_start = token_translation_data["l2_start_index"]
          l2_end = token_translation_data["l2_end_index"] + 1
          
          if l1_start >= l1_end
            Rails.logger.error("Invalid L1 indices for phrase #{p.id}: l1_start=#{l1_start} >= l1_end=#{l1_end}. Skipping this token translation.")
            next
          end
          
          if l2_start >= l2_end
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
    finish_lesson_slug = "#{self.slug}#{self.lessons.count}"
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

  # Calculate user progress for this course
  def progress_for_user(user)
    return 0 unless user
    
    # Always use fresh data to avoid stale cache issues
    total_lessons = lessons.count
    return 0 if total_lessons == 0
    
    completed_lessons = lessons.joins(:lesson_users).where(lesson_users: { user: user }).count
    ((completed_lessons.to_f / total_lessons) * 100).round
  end
end
