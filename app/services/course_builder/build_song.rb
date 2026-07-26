module CourseBuilder
  class BuildSong < Base
    # similar_sounds_for_token is the exact check render_phrase_with_blanks uses
    # to decide whether a token becomes a fillable blank in a ListenActivity.
    include ActivitiesHelper

    attr_reader :course, :progress

    # Lessons the pipeline scored at or below this are dropped as low value.
    # The pipeline scores 1-5 (pipeline/src/steps/rateLessons.ts) but does not
    # filter; deciding what to keep is this builder's call. Previously
    # CreateSong::RateLessons::LOW_VALUE_SCORE.
    LOW_VALUE_SCORE = 2

    # Activities 3 & 4 of every non-review lesson from lesson 4 onward are two
    # random picks from this pool.
    LESSON_ACTIVITY_POOL = %i[
      flashcard
      word_order
      audio_to_translation
      tokens_chain
      language_alignment
    ].freeze

    def initialize(progress, course)
      @progress = progress
      @course = course
    end

    def call
      progress.assert_current_data_format!
      previous_language = Current.translation_language
      Current.translation_language = Language.find_by(english_name: progress.translation_language)
      ActiveRecord::Base.transaction do
        course.lessons.destroy_all

        l1 = Language.find_by(english_name: progress.clip_language)
        l2 = Language.find_by(english_name: progress.translation_language)
        translation_data = progress.translation_payload(l2)
        raise "translation data is missing for #{l2.iso_name}" unless translation_data
        user = course.user
        medium = Medium.find_or_create_by!(
          url: progress.youtubeurl,
          language: l1
        )

        progress_ordered_phrases = progress.data["phrases"].each_with_index.map do |p, index|
          Phrase.create!(
            text_l1: p["text_l1"],
            timestamp: p["timestamp"],
            l1:,
            medium:,
          ).tap do |phrase|
            phrase.phrase_translations.create!(language: l2, text: translation_data.dig("phrases", index, "text"))
          end
        end
        phrases = medium.phrases.order(timestamp: :asc)

        begin
          if progress.data.dig("phrases", 0, "words").present?
            # Word-timed pipeline: each word becomes a karaoke-capable token.
            progress_ordered_phrases.each_with_index do |phrase, idx|
              words = progress.data["phrases"][idx]["words"].each_with_index.map do |word, word_index|
                word.merge("translation" => translation_data.dig("phrases", idx, "words", word_index))
              end
              phrase.build_word_tokens(words, language: l2)
              phrase.save
            end
          else
            # Legacy pipeline: parse the L1<->L2 alignment blocks.
            t = TokenTranslationParser.new(progress_ordered_phrases, progress.data["phrases_with_token_translations"])
            t.call
            progress_ordered_phrases.each { |p| p.save }
          end
        rescue => e
          Rails.logger.warn "Token translation parsing failed: #{e.message}. Continuing course creation without token translations."
        end

        begin
          t = SimilarSoundParser.new(progress_ordered_phrases, progress.data["similar_sounds"])
          t.call
          progress_ordered_phrases.each { |p| p.save }
        rescue => e
          Rails.logger.warn "Similar sound parsing failed: #{e.message}. Continuing course creation without similar sounds."
        end

        lesson_data = progress.data["lessons"].split("\n\n")
        lesson_data = filter_low_value_lessons(lesson_data)
        @flashcard_assignments = build_flashcard_assignments(lesson_data)
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

          lesson_slug = course.unique_lesson_slug(lesson_name.slug_for_language)

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
          lesson.lesson_translations.create!(language: l2, name: lesson_name)
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

        course.course_translations.find_or_initialize_by(language: l2).tap do |localized|
          localized.name = course.name
          localized.status = :ready
          localized.save!
        end
      end
    ensure
      Current.translation_language = previous_language
    end

    # Persist one additional L2 against an existing course skeleton. No lessons,
    # activities, progress, or L1 rows are rebuilt.
    def add_translation(language)
      progress.assert_current_data_format!
      previous_language = Current.translation_language
      Current.translation_language = language
      payload = progress.translation_payload(language)
      raise ArgumentError, "translation data is missing for #{language.iso_name}" unless payload

      ActiveRecord::Base.transaction do
        phrases = course.medium.phrases.order(:timestamp).includes(:phrase_tokens).to_a
        raise "transcription shape changed" unless phrases.length == payload["phrases"].length

        phrases.each_with_index do |phrase, phrase_index|
          localized = phrase.phrase_translations.find_or_initialize_by(language: language)
          localized.text = payload.dig("phrases", phrase_index, "text")
          localized.save!

          # :id tiebreak keeps this order deterministic -- it must match the
          # order the payload's words were generated in (see
          # CreateSongProgressRebuilder#ordered_tokens).
          phrase.phrase_tokens.order(:l1_start_index, :id).each_with_index do |token, word_index|
            translated_word = payload.dig("phrases", phrase_index, "words", word_index)
            next if translated_word.blank?

            token.token_translations.find_or_initialize_by(language: language).tap do |translation|
              translation.translation = translated_word
              translation.save!
            end
          end
        end

        course.lessons.order(:order).each_with_index do |lesson, index|
          lesson.lesson_translations.find_or_initialize_by(language: language).tap do |translation|
            translation.name = lesson_name_for(payload["lessons"], index) || lesson.name
            translation.save!
          end
        end

        course.course_translations.find_or_initialize_by(language: language).tap do |translation|
          translation.name = course.name
          translation.status = :ready
          translation.save!
        end
      end
    ensure
      Current.translation_language = previous_language
    end

    private

    def lesson_name_for(lessons_text, index)
      lessons_text.to_s.split("\n\n")[index]&.lines&.first&.strip&.sub(/^#\s*/, "")
    end

    # Drop lessons the RateLessons step judged to have no teaching value (a chanted
    # nonsense hook, pure onomatopoeia, or an exact reprise of an earlier lesson).
    # Ratings are aligned to lessons by position (the rating "index" is 1-based) and
    # double-checked against the title. When no ratings are present (older progress
    # records) every lesson is kept, so the course is never left empty.
    def filter_low_value_lessons(lesson_data)
      ratings = progress.data["lesson_ratings"]
      return lesson_data if ratings.blank?

      kept = lesson_data.each_with_index.reject do |block, idx|
        rating = rating_for(ratings, block, idx)
        rating && rating["score"].to_i <= LOW_VALUE_SCORE
      end.map(&:first)

      # Never strip the course down to nothing if the model was overly harsh.
      kept.presence || lesson_data
    end

    def rating_for(ratings, block, idx)
      title = block.lines.first.to_s.strip.sub(/^#\s*/, "")
      ratings.find { |r| r["index"].to_i == idx + 1 && r["title"].to_s.strip == title } ||
        ratings.find { |r| r["index"].to_i == idx + 1 } ||
        ratings.find { |r| r["title"].to_s.strip == title }
    end

    # The first three lessons (positions 1-3, never review lessons) each get one
    # activity that is either a FlashcardActivity or a WordOrderActivity. Pre-build
    # a half/half list of those assignments and shuffle it, so the split is exactly
    # even (off by one only when the count is odd) and which lesson gets which is
    # random.
    def build_flashcard_assignments(lesson_data)
      slot_count = [lesson_data.size, 3].min

      assignments = [:word_order, :flashcard] * (slot_count / 2)
      assignments << [:word_order, :flashcard].sample if slot_count.odd?
      assignments.shuffle
    end

    def use_word_order_instead_of_flashcard?
      (@flashcard_assignments.shift || :flashcard) == :word_order
    end

    def random_phrases(phrases, count)
      phrases_array = phrases.is_a?(ActiveRecord::Relation) ? phrases.to_a : phrases
      phrases_array.sample(count)
    end

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
      phrases.includes(phrase_tokens: :localized_translation).flat_map(&:phrase_tokens)
    end

    def review_token_translations(review_phrases)
      return [] if review_phrases.empty?
      review_phrases.includes(phrase_tokens: :localized_translation).flat_map(&:phrase_tokens)
    end

    # A ListenActivity is only solvable when at least one of its phrases has a
    # token translation backed by a similar sound -- that pairing is what
    # render_phrase_with_blanks turns into a fillable blank. Without any blank the
    # activity has nothing to complete and the learner gets stuck, so we skip it.
    # Returns the token translations that would render a blank (may be empty).
    def listen_blank_tokens(phrases)
      phrase_list = phrases.is_a?(ActiveRecord::Relation) ? phrases.to_a : phrases
      phrase_list.flat_map do |phrase|
        phrase.phrase_tokens.select { |t| similar_sounds_for_token(phrase, t).present? }
      end
    end

    def distinct_token_translations_by_translation(token_translations, limit)
      return [] if token_translations.empty?
      return token_translations.first(limit) if token_translations.size <= limit

      token_translations.uniq(&:translation).first(limit)
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

      Phrase.joins(:phrase_translations)
        .where(id: ids, phrase_translations: { language_id: Current.translation_language_id })
        .select("DISTINCT ON (phrase_translations.text) phrases.*")
        .order("phrase_translations.text, phrases.id")
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
      lesson_slug = course.unique_lesson_slug(review_lesson_name.slug_for_language)

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
      # 1. ReadTranslatedActivity
      a0 = Activities::ReadTranslatedActivity.create!(lesson:, order: 1, user:)
      a0.phrases = phrases

      # 2. WatchVideoActivity
      a1 = Activities::WatchVideoActivity.create!(lesson:, order: 2, user:)
      a1.phrases = phrases

      # 3. MatchPhrasesActivity (distinct by text_l2)
      distinct_phrases = distinct_phrases_by_text_l2(phrases)
      a2 = Activities::MatchPhrasesActivity.create!(lesson:, order: 3, user:)
      a2.phrases = distinct_phrases

      # 4. FlashcardActivity or WordOrderActivity (~50/50) - at most 5, distinct by translation
      unless token_translations.empty?
        flashcard_tokens = distinct_token_translations_by_translation(token_translations, 5)
        unless flashcard_tokens.empty?
          if use_word_order_instead_of_flashcard?
            a3 = Activities::WordOrderActivity.create!(lesson:, order: 4, user:)
            a3.phrases = random_phrases(phrases, 4)
          else
            a3 = Activities::FlashcardActivity.create!(lesson:, order: 4, user:)
            a3.phrase_tokens = flashcard_tokens
          end
        end
      end

      # 5. TokenChainActivity - at most 15, distinct by translation, if possible not same as activity 4
      unless token_translations.empty?
        flashcard_token_ids = flashcard_tokens&.map(&:id) || []
        remaining_tokens = token_translations.reject { |tt| flashcard_token_ids.include?(tt.id) }

        chain_tokens = if remaining_tokens.size >= 15
          distinct_token_translations_by_translation(remaining_tokens, 15)
        else
          distinct_token_translations_by_translation(token_translations, 15)
        end

        unless chain_tokens.empty?
          a4 = Activities::TokensChainActivity.create!(lesson:, order: 5, user:)
          a4.phrase_tokens = chain_tokens
        end
      end

      # 6. SortPhrasesActivity - at most 4 phrases
      a5 = Activities::SortPhrasesActivity.create!(lesson:, order: 6, user:)
      a5.phrases = phrases.first(4)
    end

    def create_lessons_2_3_activities(lesson, phrases, current_token_translations, review_token_translations, lesson_number, user)
      # 1. ReadTranslatedActivity
      a0 = Activities::ReadTranslatedActivity.create!(lesson:, order: 1, user:)
      a0.phrases = phrases

      # 2. WatchVideoActivity
      a1 = Activities::WatchVideoActivity.create!(lesson:, order: 2, user:)
      a1.phrases = phrases

      # 3. MatchPhrasesActivity or AudioToTranslation (alternate)
      if lesson_number.odd?
        distinct_phrases = distinct_phrases_by_text_l2(phrases)
        a2 = Activities::MatchPhrasesActivity.create!(lesson:, order: 3, user:)
        a2.phrases = distinct_phrases
      else
        phrases_for_audio = phrases.is_a?(ActiveRecord::Relation) ? phrases.limit(5).to_a : phrases.first(5)
        distinct_phrases_audio = distinct_phrases_by_text_l2(phrases_for_audio)
        a2 = Activities::AudioToTranslation.create!(lesson:, order: 3, user:)
        a2.phrases = distinct_phrases_audio
      end

      # 4. FlashcardActivity or WordOrderActivity (~50/50). Flashcard uses 70% current + 30% review tokens
      unless current_token_translations.empty? && review_token_translations.empty?
        mixed_tokens = mix_content(current_token_translations, review_token_translations, 70)
        flashcard_tokens = select_tokens_from_different_phrases(mixed_tokens, 5)
        unless flashcard_tokens.empty?
          if use_word_order_instead_of_flashcard?
            a3 = Activities::WordOrderActivity.create!(lesson:, order: 4, user:)
            a3.phrases = random_phrases(phrases, 4)
          else
            a3 = Activities::FlashcardActivity.create!(lesson:, order: 4, user:)
            a3.phrase_tokens = flashcard_tokens
          end
        end
      end

      # 5. MatchTokensActivity or TokenChainActivity (alternate, 70% current + 30% review)
      unless current_token_translations.empty? && review_token_translations.empty?
        mixed_tokens = mix_content(current_token_translations, review_token_translations, 70)
        if lesson_number.odd?
          a4 = Activities::MatchTokensActivity.create!(lesson:, order: 5, user:)
          a4.phrase_tokens = mixed_tokens.sample(5)
        else
          a4 = Activities::TokensChainActivity.create!(lesson:, order: 5, user:)
          a4.phrase_tokens = mixed_tokens.sample(15)
        end
      end

      # 6. ListenActivity (only if a fillable blank can be rendered)
      listen_tokens = listen_blank_tokens(phrases)
      unless listen_tokens.empty?
        a5 = Activities::ListenActivity.create!(lesson:, order: 6, user:)
        a5.phrases = phrases
        a5.phrase_tokens = listen_tokens.uniq
      end
    end

    def create_lessons_4plus_activities(lesson, phrases, review_phrases_list, current_token_translations, review_token_translations, lesson_number, user)
      # 1. ReadTranslatedActivity
      a0 = Activities::ReadTranslatedActivity.create!(lesson:, order: 1, user:)
      a0.phrases = phrases

      # 2. WatchVideoActivity
      a1 = Activities::WatchVideoActivity.create!(lesson:, order: 2, user:)
      a1.phrases = phrases

      # 3. MatchPhrasesActivity (60% current + 40% review, distinct by text_l2)
      phrases_array = phrases.is_a?(ActiveRecord::Relation) ? phrases.to_a : phrases
      review_phrases_array = review_phrases_list.is_a?(ActiveRecord::Relation) ? review_phrases_list.to_a : review_phrases_list
      mixed_phrases = mix_content(phrases_array, review_phrases_array, 60)
      distinct_mixed_phrases = distinct_phrases_by_text_l2(mixed_phrases)
      a2 = Activities::MatchPhrasesActivity.create!(lesson:, order: 3, user:)
      a2.phrases = distinct_mixed_phrases

      # 4 & 5. Two activities chosen at random from the pool, built on this
      # lesson's content (mixing in review content where the activity supports it).
      activity_context = {
        phrases: phrases,
        phrases_array: phrases_array,
        review_phrases_array: review_phrases_array,
        current_token_translations: current_token_translations,
        review_token_translations: review_token_translations
      }
      LESSON_ACTIVITY_POOL.sample(2).each_with_index do |type, index|
        build_pooled_activity(type, lesson, index + 4, activity_context, user)
      end

      # 6. SpeakActivity OR ListenActivity (alternate, current phrases). Listen
      # needs a fillable blank; fall back to Speak when no blank can be rendered.
      listen_tokens = lesson_number.odd? ? [] : listen_blank_tokens(phrases)
      if lesson_number.odd? || listen_tokens.empty?
        a5 = Activities::SpeakActivity.create!(lesson:, order: 6, user:)
        a5.phrases = phrases
      else
        a5 = Activities::ListenActivity.create!(lesson:, order: 6, user:)
        a5.phrases = phrases
        a5.phrase_tokens = listen_tokens.uniq
      end
    end

    # Builds one pooled activity (see LESSON_ACTIVITY_POOL) at the given order.
    # Each type pulls the data it needs from the context; returns nil without
    # creating anything when the required content is missing.
    def build_pooled_activity(type, lesson, order, ctx, user)
      current_tokens = ctx[:current_token_translations]
      review_tokens = ctx[:review_token_translations]

      case type
      when :flashcard
        return if current_tokens.empty? && review_tokens.empty?
        tokens = select_tokens_from_different_phrases(mix_content(current_tokens, review_tokens, 70), 5)
        return if tokens.empty?
        activity = Activities::FlashcardActivity.create!(lesson:, order:, user:)
        activity.phrase_tokens = tokens
      when :word_order
        activity = Activities::WordOrderActivity.create!(lesson:, order:, user:)
        activity.phrases = random_phrases(ctx[:phrases], 4)
      when :audio_to_translation
        distinct_phrases = distinct_phrases_by_text_l2(mix_content(ctx[:phrases_array], ctx[:review_phrases_array], 50))
        activity = Activities::AudioToTranslation.create!(lesson:, order:, user:)
        activity.phrases = distinct_phrases.first(5)
      when :tokens_chain
        return if current_tokens.empty? && review_tokens.empty?
        activity = Activities::TokensChainActivity.create!(lesson:, order:, user:)
        activity.phrase_tokens = mix_content(current_tokens, review_tokens, 60).first(5)
      when :language_alignment
        aligned_tokens = PhraseToken
          .joins(:localized_translation)
          .where(phrase_id: ctx[:phrases_array].map(&:id))
          .where.not(token_translations: { l2_start_index: nil })
        return if aligned_tokens.empty?
        activity = Activities::LanguageAlignmentActivity.create!(lesson:, order:, user:)
        activity.phrases = ctx[:phrases]
        activity.phrase_tokens = aligned_tokens.sample(5)
      end
    end

    def create_review_lesson_activities(lesson, review_phrases, review_token_translations, user)
      # 1. LanguageAlignmentActivity on all phrases from all previous lessons in order
      tt_with_l2 = PhraseToken
        .joins(:localized_translation)
        .where(phrase_id: review_phrases.pluck(:id))
        .where.not(token_translations: { l2_start_index: nil })

      unless tt_with_l2.empty?
        a1 = Activities::LanguageAlignmentActivity.create!(lesson:, order: 1, user:)
        a1.phrases = review_phrases.order(timestamp: :asc)
        a1.phrase_tokens = tt_with_l2.sample(5)
      end

      # 2. AudioToTranslation (100% review, all completed lessons)
      review_phrases_for_audio = review_phrases.order(timestamp: :asc).limit(5).to_a
      distinct_review_phrases_audio = distinct_phrases_by_text_l2(review_phrases_for_audio)
      a2 = Activities::AudioToTranslation.create!(lesson:, order: 2, user:)
      a2.phrases = distinct_review_phrases_audio

      # 3. TokenChainActivity (100% review)
      unless review_token_translations.empty?
        a3 = Activities::TokensChainActivity.create!(lesson:, order: 3, user:)
        a3.phrase_tokens = review_token_translations.sample(5)
      end

      # 4. ListenActivity (all phrases from all previous lessons in order, only if
      # a fillable blank can be rendered)
      ordered_review_phrases = review_phrases.order(timestamp: :asc)
      listen_tokens = listen_blank_tokens(ordered_review_phrases)
      unless listen_tokens.empty?
        a4 = Activities::ListenActivity.create!(lesson:, order: 4, user:)
        a4.phrases = ordered_review_phrases
        a4.phrase_tokens = listen_tokens.uniq
      end
    end
  end
end
