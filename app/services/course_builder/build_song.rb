module CourseBuilder
  class BuildSong < Base
    attr_reader :course, :progress

    def initialize(progress, course)
      @progress = progress
      @course = course
    end

    def call
      ActiveRecord::Base.transaction do
        course.lessons.destroy_all

        l1 = Language.find_by(english_name: progress.clip_language)
        l2 = Language.find_by(english_name: progress.translation_language)
        user = course.user
        medium = Medium.find_or_create_by!(url: progress.youtubeurl) do |m|
          m.language = l1
        end

        medium.phrases.destroy_all

        phrases = progress.data["phrases"].map do |p|
          Phrase.create!(
            text_l1: p["text_l1"],
            text_l2: p["text_l2"],
            timestamp: p["timestamp"],
            l1:,
            l2:,
            medium:,
          )
        end
        phrases = medium.phrases.order(timestamp: :asc)

        begin
          t = TokenTranslationParser.new(phrases, progress.data["phrases_with_token_translations"])
          t.call
          phrases.each {|p| p.save }
        rescue => e
          Rails.logger.warn "Token translation parsing failed: #{e.message}. Continuing course creation without token translations."
        end

        begin
          t = SimilarSoundParser.new(phrases, progress.data["similar_sounds"])
          t.call
          phrases.each {|p| p.save }
        rescue => e
          Rails.logger.warn "Similar sound parsing failed: #{e.message}. Continuing course creation without similar sounds."
        end

        lessons = progress.data["lessons"].split("\n\n").each_cons(2).each_with_index.map do |(l, next_l), lesson_index|
          lesson_name = l.lines.first.strip.sub(/^#\s*/, '')
          first_timestamp = l.lines.second[0..4]
          last_timestamp = l.lines.last[0..4]
          end_timestamp = next_l ? next_l.lines.second[0..4] : nil
          lesson = Lesson.create!(
            slug: lesson_name.parameterize,
            medium:,
            course:,
            order: lesson_index + 1,
            name: lesson_name,
            user:,
            start_timestamp: first_timestamp,
            end_timestamp:
          )
          all_lesson_phrases = phrases.where("timestamp >= ? and timestamp <= ?", first_timestamp, last_timestamp)
          all_token_translations = all_lesson_phrases.includes(:token_translations).flat_map(&:token_translations)
          a1 = Activities::WatchVideoActivity.create!(lesson:, order: 1, user:)
          a1.phrases = all_lesson_phrases

          a2 = Activities::MatchPhrasesActivity.create!(lesson:, order: 2, user:)
          a2.phrases = all_lesson_phrases

          unless all_token_translations.empty?
            a3 = Activities::FlashcardActivity.create!(lesson:, order: 3, user:)
            a3.token_translations = all_token_translations.sample(5)

            a4 = Activities::MatchTokensActivity.create!(lesson:, order: 4, user:)
            a4.token_translations = all_token_translations.sample(5)
          end

          a5 = Activities::SortPhrasesActivity.create!(lesson:, order: 5, user:)
          a5.phrases = all_lesson_phrases.first(5)

          tt_with_l2 = TokenTranslation
            .joins(:phrase)
            .where(phrase: { id: all_lesson_phrases.select(:id) })
            .where.not(l2_start_index: nil)

          unless tt_with_l2.empty?
            a6 = Activities::LanguageAlignmentActivity.create!(lesson:, order: 6, user:)
            a6.phrases = all_lesson_phrases
            a6.token_translations = tt_with_l2.sample(5)
          end

          a7 = Activities::SpeakActivity.create!(lesson:, order: 7, user:)
          a7.phrases = all_lesson_phrases

          a8 = Activities::ListenActivity.create!(lesson:, order: 8, user:)
          a8.phrases = all_lesson_phrases
        end
      end
    end
  end
end
