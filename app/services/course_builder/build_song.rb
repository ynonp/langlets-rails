module CourseBuilder
  class BuildSong < Base
    attr_reader :course

    def initialize(progress, course)
      @progress = progress
      @course = course
    end

    def call
      ActiveRecord::Base.transaction do
        data_hash = collect_json_data(@progress)
        user = course.user

        Rails.logger.info("Finding languages")
        l1 = Language.find_by(english_name: data_hash[:clip_language])
        l2 = Language.find_by(english_name: data_hash[:translation_language])

        Rails.logger.info("Finding medium")
        medium = Medium.find_or_create_by!(url: data_hash[:youtubeurl])
        medium.phrases.destroy_all

        all_alignment_tokens = []
        all_listen_tokens = []

        Rails.logger.info("Creating new lessons")
        data_hash[:lessons].each_with_index do |lesson_data, lesson_index|
          Rails.logger.info("Creating lesson: #{lesson_data[:title]}")
          l = Lesson.create!(
            medium: medium,
            slug: "#{course.slug}#{lesson_index}",
            course: course,
            order: lesson_index,
            name: lesson_data[:title],
            user: user)

          a1 = Activities::WatchVideoActivity.create!(lesson: l, order: 1, user: user)
          a2 = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2, user: user)

          a3 = Activities::MatchTokensActivity.create!(lesson: l, order: 3, user: user)
          a4 = Activities::SortPhrasesActivity.create!(lesson: l, order: 4, user: user)
          a5 = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 5, user: user)
          a6 = Activities::SpeakActivity.create!(lesson: l, order: 6, user: user)

          phrases = lesson_data[:phrases].each_with_index.map do |phrase_data, phrase_index|
            p = Phrase.create!(
              text_l1_attributes: {
                language: l1,
                script_variants_attributes: [
                  { script: l1.default_script, content: phrase_data[:text_l1] }
                ]
              },
              text_l2_attributes: {
                language: l2,
                script_variants_attributes: [
                  { script: l2.default_script, content: phrase_data[:text_l2] }
                ]
              },
              timestamp: phrase_data[:timestamp],
              medium:,
              l1:,
              l2:,
            )
            phrase_data.fetch(:text_l1_variants, []).each do |script_variant|
              script = Script.find_by(code: script_variant[:script])
              p.text_l1.add_variant!(script:, content: script_variant[:content])
            end

            (phrase_data[:translations] || []).each do |token_translation_data|
              # Validate indices before attempting DB creation
              l1_start = token_translation_data[:l1_index].first
              l1_end = token_translation_data[:l1_index].last
              l2_start = token_translation_data[:l2_index]&.first
              l2_end = token_translation_data[:l2_index]&.last

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
                  translation: token_translation_data["translation"],
                )

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
        end

        medium.reload
        finish_lesson_slug = "#{course.slug}#{course.lessons.count}"
        finish_lesson = Lesson.create!(
          medium: medium,
          slug: finish_lesson_slug,
          course: course,
          order: course.lessons.count,
          name: "Song Review",
          user: user
        )
        a1 = Activities::WatchVideoActivity.create!(lesson: finish_lesson, order: 1, user: user)
        a2 = Activities::MatchTokensActivity.create!(lesson: finish_lesson, order: 2, user: user)
        a3 = Activities::LanguageAlignmentActivity.create!(lesson: finish_lesson, order: 3, user: user)

        a1.phrases = medium.phrases.ordered_by_timestamp
        a2.token_translations = medium.phrases.flat_map(&:token_translations).sample(50)

        a3.phrases = medium.phrases.ordered_by_timestamp
        a3.token_translations = all_alignment_tokens
      end
    end
  end
end
