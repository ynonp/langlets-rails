module Activities
  class ListenActivity < Activity
    def activity_params
      {
        **video_params,
        rtl: phrases.first.l1.rtl,
        phrases: phrases.ordered_by_timestamp.includes(:localized_translation, :similar_sounds, phrase_tokens: :localized_translation),
        activity_translation_ids: phrase_tokens.ids,
      }
    end
  end
end
