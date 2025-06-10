module Activities
  class MatchPhrasesActivity < Activity
    def activity_params
      {
        **video_params,
        phrases: processed_phrases,
        all_l2_texts: lesson.medium.phrases.map {|p| p.text_l2 }.uniq,
        l1: phrases.first.l1,
        l2: phrases.first.l2
      }
    end

    def ordered_phrases
      @ordered_phrases ||= phrases.ordered_by_timestamp.includes(token_translations: { l1_audio_attachment: :blob }).to_a
    end

    private

    def processed_phrases
      @all_medium_phrases ||= lesson.medium.phrases.ordered_by_timestamp.to_a

      @processed_phrases ||= begin
        phrases_array = ordered_phrases
        phrases_array.each_with_index do |phrase, index|
          next_phrase = phrases_array[index + 1]
          current_phrase_index = @all_medium_phrases.find_index { |p| p.id == phrase.id }
          next_phrase = current_phrase_index ? @all_medium_phrases[current_phrase_index + 1] : nil

          timestamp_end = next_phrase&.timestamp || to_string_timestamp(phrase.timestamp_seconds + 5)
          
          phrase.define_singleton_method(:calculated_end_timestamp) { timestamp_end }
        end
        phrases_array
      end
    end
  end
end
