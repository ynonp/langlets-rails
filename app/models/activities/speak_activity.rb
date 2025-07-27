module Activities
  class SpeakActivity < Activity
    def activity_params
      first_phrase = ordered_phrases.first
      l1 = first_phrase&.l1
      l2 = first_phrase&.l2
      
      {
        **video_params,
        azure_speech_name: l1&.pronunciation_variant_name,
        l1: l1&.english_name,
        l2: l2&.english_name,
        l1_rtl: l1&.rtl,
        l2_rtl: l2&.rtl,
        phrases: processed_phrases,
      }
    end

    private

    def processed_phrases
      @processed_phrases ||= begin
        all_medium_phrases = lesson.medium.phrases.to_a  # Use preloaded medium phrases
        Phrase.with_calculated_end_timestamps(ordered_phrases, all_medium_phrases)
      end
    end

    def video_params
      first_phrase = processed_phrases.first
      {
        video_id: lesson.medium.extract_youtube_video_id,
        start_timestamp: first_phrase&.timestamp,
        end_timestamp: first_phrase&.calculated_end_timestamp
      }
    end
  end
end
