module Activities
  class SpeakActivity < Activity
    def activity_params
      {
        **video_params,
        azure_speech_name: phrases.ordered_by_timestamp.first.l1.pronunciation_variant_name,
        l1: phrases.ordered_by_timestamp.first.l1.english_name,
        l2: phrases.ordered_by_timestamp.first.l2.english_name,
        phrases: phrases.ordered_by_timestamp.includes(:token_translations),
      }
    end
  end
end
