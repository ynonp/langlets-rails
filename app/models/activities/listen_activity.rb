module Activities
  class ListenActivity < Activity
    def activity_params
      {
        **video_params,
        rtl: phrases.first.l1.rtl,
        phrases: phrases.ordered_by_timestamp.includes(:similar_sounds),
        activity_translation_ids: token_translations.ids,
      }
    end
  end
end
