module Activities
  class ListenActivity < Activity
    def activity_params
      ordered = phrases.ordered_by_timestamp.includes(:localized_translation, :similar_sounds, phrase_tokens: :localized_translation).to_a

      {
        **video_params,
        rtl: ordered.first.l1.rtl,
        phrases: ordered,
        video_player: true,
        interactive_video_player: true,
        preload_player: true,
        word_timing: word_timing_enabled?(ordered),
        activity_translation_ids: phrase_tokens.ids,
      }
    end

    private

    def word_timing_enabled?(ordered_phrases)
      ordered_phrases.all? do |phrase|
        phrase.phrase_tokens.present? && phrase.phrase_tokens.all?(&:karaoke?)
      end
    end
  end
end
