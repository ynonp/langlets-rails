module Activities
  class SpeakActivity < Activity
    def activity_params
      l1 = phrases.ordered_by_timestamp.first.l1
      l2 = phrases.ordered_by_timestamp.first.l2
      {
        **video_params,
        azure_speech_name: phrases.ordered_by_timestamp.first.l1.pronunciation_variant_name,
        l1: l1.english_name,
        l2: l2.english_name,
        l1_rtl: l1.rtl,
        l2_rtl: l2.rtl,
        phrases: phrases.ordered_by_timestamp.includes(:token_translations),
      }
    end
  end
end
