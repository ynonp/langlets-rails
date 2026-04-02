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
          phrases.each { |p| p.save }
        rescue => e
          Rails.logger.warn "Token translation parsing failed: #{e.message}. Continuing course creation without token translations."
        end

        begin
          t = SimilarSoundParser.new(phrases, progress.data["similar_sounds"])
          t.call
          phrases.each { |p| p.save }
        rescue => e
          Rails.logger.warn "Similar sound parsing failed: #{e.message}. Continuing course creation without similar sounds."
        end

        lesson_data = progress.data["lessons"].split("\n\n")
        lesson_index = 0
        created_lessons = []

        lesson_data.each_with_index do |l, idx|
          next_l = lesson_data[idx + 1]
          lesson_name = l.lines.first.strip.sub(/^#\s*/, "")
          first_timestamp = l.lines.second[0..7]
          last_timestamp = l.lines.last[0..7]
          end_timestamp = next_l ? next_l.lines.second[0..7] : nil

          lesson_index += 1
          lesson_number = lesson_index

          lesson_slug = course.unique_lesson_slug(lesson_name.parameterize)

          lesson = Lesson.create!(
            slug: lesson_slug,
            medium:,
            course:,
            order: lesson_number,
            name: lesson_name,
            user:,
            start_timestamp: first_timestamp,
            end_timestamp:
          )
          created_lessons << lesson

          all_lesson_phrases = current_lesson_phrases(lesson, phrases, first_timestamp, last_timestamp)
          all_token_translations = current_token_translations(all_lesson_phrases)

          if is_review_lesson?(lesson_number)
            review_phrases_list = review_phrases(lesson, phrases, created_lessons)
            review_token_translations_list = review_token_translations(review_phrases_list)
            create_review_lesson_activities(lesson, review_phrases_list, review_token_translations_list, user)
          elsif lesson_number == 1
            create_lesson_1_activities(lesson, all_lesson_phrases, all_token_translations, user)
          elsif lesson_number <= 3
            review_phrases_list = review_phrases(lesson, phrases, created_lessons)
            review_token_translations_list = review_token_translations(review_phrases_list)
            create_lessons_2_3_activities(lesson, all_lesson_phrases, all_token_translations, review_token_translations_list, lesson_number, user)
          else
            review_phrases_list = review_phrases(lesson, phrases, created_lessons)
            review_token_translations_list = review_token_translations(review_phrases_list)
            create_lessons_4plus_activities(lesson, all_lesson_phrases, review_phrases_list, all_token_translations, review_token_translations_list, lesson_number, user)
          end

          # Check if we need to insert a review lesson after this one (every 4th lesson)
          if should_insert_review_lesson?(lesson_number)
            lesson_index += 1
            review_lesson = create_review_lesson(created_lessons, medium, user, lesson_index)
            if review_lesson
              created_lessons << review_lesson
              review_phrases_list = review_phrases(review_lesson, phrases, created_lessons)
              review_token_translations_list = review_token_translations(review_phrases_list)
              create_review_lesson_activities(review_lesson, review_phrases_list, review_token_translations_list, user)
            end
          end
        end
      end
    end

    private

    def current_lesson_phrases(lesson, all_phrases, first_timestamp, last_timestamp)
      all_phrases.where("timestamp >= ? and timestamp <= ?", first_timestamp, last_timestamp)
    end

    def review_phrases(lesson, all_phrases, created_lessons)
      previous_lessons = created_lessons.select { |l| l.order < lesson.order }
      return Phrase.none if previous_lessons.empty?

      phrase_ids = previous_lessons.flat_map do |prev_lesson|
        all_phrases.where("timestamp >= ? and timestamp <= ?", prev_lesson.start_timestamp, prev_lesson.end_timestamp || prev_lesson.start_timestamp).pluck(:id)
      end

      all_phrases.where(id: phrase_ids).order(timestamp: :asc)
    end

    def current_token_translations(phrases)
      phrases.includes(:token_translations).flat_map(&:token_translations)
    end

    def review_token_translations(review_phrases)
      return [] if review_phrases.empty?
      review_phrases.includes(:token_translations).flat_map(&:token_translations)
    end

    def distinct_token_translations_by_translation(token_translations, limit)
      return [] if token_translations.empty?
      return token_translations.first(limit) if token_translations.size <= limit

      ids = token_translations.map(&:id)
      TokenTranslation.select("distinct on (translation) *")
        .where(id: ids)
        .order(:translation, :id)
        .limit(limit)
        .to_a
    end

    def distinct_phrases_by_text_l1(phrases)
      return [] if phrases.nil? || (phrases.respond_to?(:empty?) && phrases.empty?)

      # If it's an ActiveRecord::Relation, check if empty
      if phrases.is_a?(ActiveRecord::Relation)
        return [] if phrases.none?
        ids = phrases.pluck(:id)
      else
        # It's an array
        return [] if phrases.empty?
        ids = phrases.map(&:id)
      end

      return phrases if ids.empty?

      Phrase.select("distinct on (text_l1) *")
        .where(id: ids)
        .order(:text_l1, :id)
        .to_a
    end

    def distinct_phrases_by_text_l2(phrases)
      return [] if phrases.nil? || (phrases.respond_to?(:empty?) && phrases.empty?)

      # If it's an ActiveRecord::Relation, check if empty
      if phrases.is_a?(ActiveRecord::Relation)
        return [] if phrases.none?
        ids = phrases.pluck(:id)
      else
        # It's an array
        return [] if phrases.empty?
        ids = phrases.map(&:id)
      end

      return phrases if ids.empty?

      Phrase.select("distinct on (text_l2) *")
        .where(id: ids)
        .order(:text_l2, :id)
        .to_a
    end

    def mix_content(current_items, review_items, current_percent)
      # Convert to arrays if they're ActiveRecord::Relation
      current_array = current_items.is_a?(ActiveRecord::Relation) ? current_items.to_a : current_items
      review_array = review_items.is_a?(ActiveRecord::Relation) ? review_items.to_a : review_items

      return [] if current_array.empty? && review_array.empty?

      total_needed = [ current_array.size + review_array.size, 10 ].min
      current_count = [ (total_needed * current_percent / 100.0).ceil, current_array.size ].min
      review_count = [ total_needed - current_count, review_array.size ].min

      current_selected = current_array.sample(current_count)
      review_selected = review_array.sample(review_count)

      (current_selected + review_selected).shuffle
    end

    def select_tokens_from_different_phrases(token_translations, limit)
      return [] if token_translations.empty?

      # Group by phrase_id
      grouped = token_translations.group_by(&:phrase_id)

      # Select one token from each phrase until we reach the limit
      selected = []
      phrase_ids = grouped.keys.shuffle

      phrase_ids.each do |phrase_id|
        break if selected.size >= limit
        tokens_for_phrase = grouped[phrase_id]
        selected << tokens_for_phrase.sample
      end

      # If we still need more, fill from remaining tokens
      remaining = token_translations - selected
      while selected.size < limit && !remaining.empty?
        selected << remaining.sample
        remaining.delete(selected.last)
      end

      selected.first(limit)
    end

    def is_review_lesson?(lesson_number)
      # Review lessons at positions 4, 8, 12, etc. (every 4th lesson)
      lesson_number > 0 && lesson_number % 4 == 0
    end

    def should_insert_review_lesson?(lesson_number)
      # Check if we should insert a review lesson after this lesson
      # Review lessons should be inserted after lessons 3, 7, 11, etc. (every 4th lesson)
      lesson_number > 0 && lesson_number % 4 == 3
    end

    def create_review_lesson(created_lessons, medium, user, lesson_index)
      return nil if created_lessons.empty?

      review_number = (lesson_index / 4.0).ceil
      review_lesson_name = "Review Lesson #{review_number}"
      lesson_slug = course.unique_lesson_slug(review_lesson_name.parameterize)

      # Get the first and last timestamps from all previous lessons
      previous_lessons = created_lessons
      return nil if previous_lessons.empty?

      first_timestamp = previous_lessons.first.start_timestamp
      last_timestamp = previous_lessons.map { |l| l.end_timestamp || l.start_timestamp }.compact.max

      Lesson.create!(
        slug: lesson_slug,
        medium:,
        course:,
        order: lesson_index,
        name: review_lesson_name,
        user:,
        start_timestamp: first_timestamp,
        end_timestamp: last_timestamp
      )
    end

    def create_lesson_1_activities(lesson, phrases, token_translations, user)
      # 1. WatchVideoActivity
      a1 = Activities::WatchVideoActivity.create!(lesson:, order: 1, user:)
      a1.phrases = phrases

      # 2. MatchPhrasesActivity (distinct by text_l2)
      distinct_phrases = distinct_phrases_by_text_l2(phrases)
      a2 = Activities::MatchPhrasesActivity.create!(lesson:, order: 2, user:)
      a2.phrases = distinct_phrases

      # 3. FlashcardActivity - at most 5, distinct by translation
      unless token_translations.empty?
        flashcard_tokens = distinct_token_translations_by_translation(token_translations, 5)
        unless flashcard_tokens.empty?
          a3 = Activities::FlashcardActivity.create!(lesson:, order: 3, user:)
          a3.token_translations = flashcard_tokens
        end
      end

      # 4. TokenChainActivity - at most 15, distinct by translation, if possible not same as activity 3
      unless token_translations.empty?
        flashcard_token_ids = flashcard_tokens&.map(&:id) || []
        remaining_tokens = token_translations.reject { |tt| flashcard_token_ids.include?(tt.id) }

        chain_tokens = if remaining_tokens.size >= 15
          distinct_token_translations_by_translation(remaining_tokens, 15)
        else
          distinct_token_translations_by_translation(token_translations, 15)
        end

        unless chain_tokens.empty?
          a4 = Activities::TokensChainActivity.create!(lesson:, order: 4, user:)
          a4.token_translations = chain_tokens
        end
      end

      # 5. SortPhrasesActivity - at most 4 phrases
      a5 = Activities::SortPhrasesActivity.create!(lesson:, order: 5, user:)
      a5.phrases = phrases.first(4)
    end

    def create_lessons_2_3_activities(lesson, phrases, current_token_translations, review_token_translations, lesson_number, user)
      # 1. WatchVideoActivity
      a1 = Activities::WatchVideoActivity.create!(lesson:, order: 1, user:)
      a1.phrases = phrases

      # 2. MatchPhrasesActivity or AudioToTranslation (alternate)
      if lesson_number.odd?
        distinct_phrases = distinct_phrases_by_text_l2(phrases)
        a2 = Activities::MatchPhrasesActivity.create!(lesson:, order: 2, user:)
        a2.phrases = distinct_phrases
      else
        phrases_for_audio = phrases.is_a?(ActiveRecord::Relation) ? phrases.limit(5).to_a : phrases.first(5)
        distinct_phrases_audio = distinct_phrases_by_text_l2(phrases_for_audio)
        a2 = Activities::AudioToTranslation.create!(lesson:, order: 2, user:)
        a2.phrases = distinct_phrases_audio
      end

      # 3. FlashcardActivity (70% current + 30% review tokens) - select from different phrases
      unless current_token_translations.empty? && review_token_translations.empty?
        mixed_tokens = mix_content(current_token_translations, review_token_translations, 70)
        flashcard_tokens = select_tokens_from_different_phrases(mixed_tokens, 5)
        unless flashcard_tokens.empty?
          a3 = Activities::FlashcardActivity.create!(lesson:, order: 3, user:)
          a3.token_translations = flashcard_tokens
        end
      end

      # 4. MatchTokensActivity or TokenChainActivity (alternate, 70% current + 30% review)
      unless current_token_translations.empty? && review_token_translations.empty?
        mixed_tokens = mix_content(current_token_translations, review_token_translations, 70)
        if lesson_number.odd?
          a4 = Activities::MatchTokensActivity.create!(lesson:, order: 4, user:)
          a4.token_translations = mixed_tokens.sample(5)
        else
          a4 = Activities::TokensChainActivity.create!(lesson:, order: 4, user:)
          a4.token_translations = mixed_tokens.sample(15)
        end
      end

      # 5. ListenActivity
      a5 = Activities::ListenActivity.create!(lesson:, order: 5, user:)
      a5.phrases = phrases
    end

    def create_lessons_4plus_activities(lesson, phrases, review_phrases_list, current_token_translations, review_token_translations, lesson_number, user)
      # 1. WatchVideoActivity
      a1 = Activities::WatchVideoActivity.create!(lesson:, order: 1, user:)
      a1.phrases = phrases

      # 2. MatchPhrasesActivity (60% current + 40% review, distinct by text_l2)
      phrases_array = phrases.is_a?(ActiveRecord::Relation) ? phrases.to_a : phrases
      review_phrases_array = review_phrases_list.is_a?(ActiveRecord::Relation) ? review_phrases_list.to_a : review_phrases_list
      mixed_phrases = mix_content(phrases_array, review_phrases_array, 60)
      distinct_mixed_phrases = distinct_phrases_by_text_l2(mixed_phrases)
      a2 = Activities::MatchPhrasesActivity.create!(lesson:, order: 2, user:)
      a2.phrases = distinct_mixed_phrases

      # 3. AudioToTranslation (50% current + 50% review)
      mixed_phrases_audio = mix_content(phrases_array, review_phrases_array, 50)
      distinct_mixed_phrases_audio = distinct_phrases_by_text_l2(mixed_phrases_audio)
      a3 = Activities::AudioToTranslation.create!(lesson:, order: 3, user:)
      a3.phrases = distinct_mixed_phrases_audio.first(5)

      # 4. TokenChainActivity (60% current + 40% review)
      unless current_token_translations.empty? && review_token_translations.empty?
        mixed_tokens = mix_content(current_token_translations, review_token_translations, 60)
        a4 = Activities::TokensChainActivity.create!(lesson:, order: 4, user:)
        a4.token_translations = mixed_tokens.first(5)
      end

      # 5. SpeakActivity OR ListenActivity (alternate, current phrases)
      if lesson_number.odd?
        a5 = Activities::SpeakActivity.create!(lesson:, order: 5, user:)
        a5.phrases = phrases
      else
        a5 = Activities::ListenActivity.create!(lesson:, order: 5, user:)
        a5.phrases = phrases
      end
    end

    def create_review_lesson_activities(lesson, review_phrases, review_token_translations, user)
      # 1. LanguageAlignmentActivity on all phrases from all previous lessons in order
      tt_with_l2 = TokenTranslation
        .joins(:phrase)
        .where(phrase: { id: review_phrases.pluck(:id) })
        .where.not(l2_start_index: nil)

      unless tt_with_l2.empty?
        a1 = Activities::LanguageAlignmentActivity.create!(lesson:, order: 1, user:)
        a1.phrases = review_phrases.order(timestamp: :asc)
        a1.token_translations = tt_with_l2.sample(5)
      end

      # 2. AudioToTranslation (100% review, all completed lessons)
      review_phrases_for_audio = review_phrases.order(timestamp: :asc).limit(5).to_a
      distinct_review_phrases_audio = distinct_phrases_by_text_l2(review_phrases_for_audio)
      a2 = Activities::AudioToTranslation.create!(lesson:, order: 2, user:)
      a2.phrases = distinct_review_phrases_audio

      # 3. TokenChainActivity (100% review)
      unless review_token_translations.empty?
        a3 = Activities::TokensChainActivity.create!(lesson:, order: 3, user:)
        a3.token_translations = review_token_translations.sample(5)
      end

      # 4. ListenActivity (all phrases from all previous lessons in order)
      a4 = Activities::ListenActivity.create!(lesson:, order: 4, user:)
      a4.phrases = review_phrases.order(timestamp: :asc)
    end
  end
end
