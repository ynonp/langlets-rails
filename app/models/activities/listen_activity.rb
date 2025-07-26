module Activities
  class ListenActivity < Activity
    def activity_params(current_script: nil)
      activity_translation_ids = token_translations.ids
      {
        **video_params,
        rtl: phrases.first.l1.rtl,
        phrases: phrases.ordered_by_timestamp.includes(:token_translations),
      }
    end
  end
end
