module Activities
  class ListenActivity < Activity
    def activity_params
      activity_translation_ids = token_translations.ids
      {
        **video_params,
        rtl: phrases.first.l1.rtl,
        phrases: phrases.ordered_by_timestamp.includes(:text_l1 => :script_variants, :text_l2 => :script_variants, :token_translations => []),
      }
    end
  end
end
