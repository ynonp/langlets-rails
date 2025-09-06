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
        medium = Medium.find_or_create_by!(url: data_hash[:youtubeurl]) do |m|
          m.language = l1
        end
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
              text_l1: phrase_data[:text_l1],
              text_l2: phrase_data[:text_l2],
              timestamp: phrase_data[:timestamp],
              medium:,
              l1:,
              l2:,
            )


            # Collect and validate all token translations for this phrase before creating them
            token_translations_data = []
            (phrase_data[:translations] || []).each do |token_translation_data|
              # Validate indices before attempting DB creation
              l1_start = token_translation_data[:l1_index].first
              l1_end = token_translation_data[:l1_index].last

              if phrase_data[:translation_text] == p.text_l2
                l2_start = token_translation_data[:l2_index]&.first
                l2_end = token_translation_data[:l2_index]&.last
              else
                # AI used a different translation for l2, so alignment is not valid
                l2_start = nil
                l2_end = nil
              end

              if l1_start > l1_end
                Rails.logger.error("Invalid L1 indices for phrase #{p.id}: l1_start=#{l1_start} >= l1_end=#{l1_end}. Skipping this token translation.")
                next
              end

              if l2_start.present? && l2_end.present? && (l2_start > l2_end)
                Rails.logger.error("Invalid L2 indices for phrase #{p.id}: l2_start=#{l2_start} >= l2_end=#{l2_end}. Skipping this token translation.")
                next
              end

              token_translations_data << {
                l1_start: l1_start,
                l1_end: l1_end,
                l2_start: l2_start,
                l2_end: l2_end,
                translation: token_translation_data[:translation],
                language_alignment_activity: token_translation_data[:language_alignment_activity]
              }
            end

            # Check for overlapping token translations
            validate_no_overlapping_tokens!(token_translations_data, p)

            # Create token translations after validation
            token_translations_data.each do |token_data|
              begin
                t = TokenTranslation.create!(
                  phrase: p,
                  l1_start_index: token_data[:l1_start],
                  l2_start_index: token_data[:l2_start],
                  l1_end_index: token_data[:l1_end],
                  l2_end_index: token_data[:l2_end],
                  translation: token_data[:translation],
                )

                if token_data[:language_alignment_activity] == 1
                  a5.token_translations << t
                  all_alignment_tokens << t
                end
              rescue ActiveRecord::RecordNotUnique => e
                Rails.logger.error("Duplicate token translation for phrase #{p.id}: l1_start=#{token_data[:l1_start]}, l1_end=#{token_data[:l1_end]}. Skipping duplicate. Error: #{e.message}")
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

    private

    def validate_no_overlapping_tokens!(token_translations_data, phrase)
      return if token_translations_data.empty?

      # Sort tokens by start index for easier comparison
      sorted_tokens = token_translations_data.sort_by { |t| t[:l1_start] }
      
      sorted_tokens.each_with_index do |current_token, i|
        # Check against all subsequent tokens
        sorted_tokens[(i + 1)..-1].each do |other_token|
          if tokens_overlap?(current_token, other_token)
            words = phrase.text_l1.split
            current_text = words[current_token[:l1_start]..current_token[:l1_end]].join(' ')
            other_text = words[other_token[:l1_start]..other_token[:l1_end]].join(' ')
            
            raise ArgumentError, "Overlapping token translations detected in phrase '#{phrase.text_l1}': " \
                               "'#{current_text}' (#{current_token[:l1_start]}..#{current_token[:l1_end]}) " \
                               "overlaps with '#{other_text}' (#{other_token[:l1_start]}..#{other_token[:l1_end]})"
          end
        end
      end
    end

    def tokens_overlap?(token1, token2)
      # Two tokens overlap if their ranges intersect
      # Token 1: [start1, end1], Token 2: [start2, end2]
      # They overlap if: start1 <= end2 && start2 <= end1
      token1[:l1_start] <= token2[:l1_end] && token2[:l1_start] <= token1[:l1_end]
    end
  end
end
