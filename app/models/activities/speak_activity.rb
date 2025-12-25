module Activities
  class SpeakActivity < Activity
    include ActivityWithTokens

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
        phrases: phrases_with_calculated_end_timestamps,
      }
    end

    private

    def video_params
      first_phrase = phrases_with_calculated_end_timestamps.first
      {
        video_id: lesson.medium.extract_youtube_video_id,
        start_timestamp: first_phrase&.timestamp,
        end_timestamp: first_phrase&.calculated_end_timestamp
      }
    end
  end
end
