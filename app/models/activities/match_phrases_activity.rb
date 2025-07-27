module Activities
  class MatchPhrasesActivity < Activity
    def activity_params
      {
        **video_params,
        phrases: processed_phrases,
        all_l2_phrases: lesson.medium.phrases.to_a,  # Pass phrase objects instead of text
        l1: phrases.first.l1,
        l2: phrases.first.l2
      }
    end

    def ordered_phrases
      @ordered_phrases ||= phrases.ordered_by_timestamp.includes(token_translations: { l1_audio_attachment: :blob }).to_a
    end

    private

    def processed_phrases
      @processed_phrases ||= begin
        all_medium_phrases = lesson.medium.phrases.ordered_by_timestamp.to_a
        Phrase.with_calculated_end_timestamps(ordered_phrases, all_medium_phrases)
      end
    end
  end
end
