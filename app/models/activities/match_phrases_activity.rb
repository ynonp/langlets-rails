module Activities
  class MatchPhrasesActivity < Activity
    def activity_params
      {
        **video_params,
        phrases: processed_phrases,
        all_l2_phrases: lesson.medium.phrases.to_a,  # Use preloaded medium phrases
        l1: cached_l1_language,
        l2: cached_l2_language
      }
    end

    private

    def processed_phrases
      @processed_phrases ||= begin
        all_medium_phrases = lesson.medium.phrases.to_a  # Use preloaded medium phrases
        Phrase.with_calculated_end_timestamps(ordered_phrases, all_medium_phrases)
      end
    end

    def cached_l1_language
      @cached_l1_language ||= ordered_phrases.first&.l1
    end

    def cached_l2_language
      @cached_l2_language ||= ordered_phrases.first&.l2
    end
  end
end
