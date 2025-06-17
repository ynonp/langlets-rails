class Course < ApplicationRecord
  has_many :lessons, -> { order(order: :asc) }, dependent: :destroy

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
        name: lesson_data["title"])

      a1 = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
      a2 = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
      a3 = Activities::WordOrderActivity.create!(lesson: l, order: 4)
      a5 = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 5)
      a8 = Activities::MatchTokensActivity.create!(lesson: l, order: 3)

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
          t = TokenTranslation.create!(
            phrase: p,
            l1_start_index: token_translation_data["l1_start_index"],
            l2_start_index: token_translation_data["l2_start_index"],
            l1_end_index: token_translation_data["l1_end_index"] + 1,
            l2_end_index: token_translation_data["l2_end_index"] + 1,
            similar_sound: token_translation_data["similar_sound"],
            translation: token_translation_data["translation"],
          )

          # a7.token_translations << t if token_translation_data["listening_activity"] == 1
          a5.token_translations << t if token_translation_data["language_alignment_activity"] == 1
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
      name: "Final Review"
      )
    a1 = Activities::WatchVideoActivity.create!(lesson: finish_lesson, order: 1)
    a2 = Activities::MatchTokensActivity.create!(lesson: finish_lesson, order: 2)
    a3 = Activities::LanguageAlignmentActivity.create!(lesson: finish_lesson, order: 3)

    a1.phrases = medium.phrases.ordered_by_timestamp
    a2.token_translations = medium.phrases.flat_map(&:token_translations).sample(50)
    a3.phrases = medium.phrases.ordered_by_timestamp
    a3.token_translations = medium.phrases.flat_map(&:token_translations).sample(50)
  end

  def create_song!(progress)
    raise "Missing creation data" unless progress.ready?
    data = progress.data

    l1 = Language.find_by(english_name: progress.clip_language)
    l2 = Language.find_by(english_name: progress.translation_language)
    medium = Medium.find_or_create_by!(url: progress.youtubeurl)

    all_alignment_tokens = []
    all_listen_tokens = []

    self.lessons.destroy_all
    Lesson.where("slug like \'#{slug}%\'").destroy_all
    medium.phrases.destroy_all

    data["lessons"].each_with_index do |lesson_data, lesson_index|
      l = Lesson.create!(
        medium: medium,
        slug: "#{slug}#{lesson_index}",
        course: self,
        order: lesson_index,
        name: lesson_data["title"])

      a1 = Activities::WatchVideoActivity.create!(lesson: l, order: 1)

      a2 = if rand() > 0.5
             Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
           else
             Activities::WordOrderActivity.create!(lesson: l, order: 2)
           end
      a3 = Activities::MatchTokensActivity.create!(lesson: l, order: 3)
      a4 = Activities::SortPhrasesActivity.create!(lesson: l, order: 4)
      a5 = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 5)
      a6 = Activities::SpeakActivity.create!(lesson: l, order: 6)
      a7 = Activities::ListenActivity.create!(lesson: l, order: 7)

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
          t = TokenTranslation.create!(
            phrase: p,
            l1_start_index: token_translation_data["l1_start_index"],
            l2_start_index: token_translation_data["l2_start_index"],
            l1_end_index: token_translation_data["l1_end_index"] + 1,
            l2_end_index: token_translation_data["l2_end_index"] + 1,
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
      name: "Song Review"
      )
    a1 = Activities::WatchVideoActivity.create!(lesson: finish_lesson, order: 1)
    a2 = Activities::MatchTokensActivity.create!(lesson: finish_lesson, order: 2)
    a3 = Activities::LanguageAlignmentActivity.create!(lesson: finish_lesson, order: 3)
    a4 = Activities::ListenActivity.create!(lesson: finish_lesson, order: 4)

    a1.phrases = medium.phrases.ordered_by_timestamp
    a2.token_translations = medium.phrases.flat_map(&:token_translations).sample(50)

    a3.phrases = medium.phrases.ordered_by_timestamp
    a3.token_translations = all_alignment_tokens

    a4.phrases = medium.phrases.ordered_by_timestamp
    a4.token_translations = all_listen_tokens
  end
end
