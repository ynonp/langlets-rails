module Activities
  class SpeakActivity < Activity
    def activity_params
      {
        **video_params,
        azure_speech_name: phrases.first.l1.pronunciation_variant_name,
        l1: phrases.first.l1.english_name,
        l2: phrases.first.l2.english_name,
        phrases: phrases.includes(:token_translations),
      }
    end
  end
end
