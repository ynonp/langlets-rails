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
        phrases: processed_phrases,
      }
    end

    def ordered_phrases
      @ordered_phrases ||= phrases.ordered_by_timestamp.includes(:token_translations).to_a
    end

    private

    def processed_phrases
      @all_medium_phrases ||= lesson.medium.phrases.ordered_by_timestamp.to_a

      @processed_phrases ||= begin
        phrases_array = ordered_phrases
        phrases_array.each_with_index do |phrase, index|
          current_phrase_index = @all_medium_phrases.find_index { |p| p.id == phrase.id }
          next_phrase = current_phrase_index ? @all_medium_phrases[current_phrase_index + 1] : nil

          timestamp_end = next_phrase&.timestamp || to_string_timestamp(phrase.timestamp_seconds + 5)
          
          phrase.define_singleton_method(:calculated_end_timestamp) { timestamp_end }
        end
        phrases_array
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
