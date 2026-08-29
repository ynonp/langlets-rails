module Activities
  class WordOrderActivity < Activity
    include ActivityWithMediaPlayback

    def activity_params
      phrases_data_for_activity = phrases_with_playback_boundaries.map do |phrase|
        {
          l2_text: phrase.text_l2,
          l1_text: phrase.text_l1,
          timestamp_start: phrase.timestamp,
          timestamp_end: phrase.calculated_end_timestamp,
          word_segments: build_word_segments_for_phrase(phrase)
        }
      end

      {
        **video_params,
        phrases: phrases_data_for_activity,
        l1: ordered_phrases.first.l1,
        l2: ordered_phrases.first.l2
      }
    end

    private

    def build_word_segments_for_phrase(phrase)
      # Get token translations for this phrase that are associated with this activity
      tokens = phrase.phrase_tokens.to_a.sort_by(&:l1_start_index)

      return fallback_word_segments(phrase.text_l1) if tokens.empty?

      segments = []
      current_position = 0
      text_length = phrase.text_l1.to_s.length

      tokens.each do |token|
        # Add static text before this token if there's a gap
        if current_position < token.l1_start_character_index
          static_text = phrase.text_l1[current_position...token.l1_start_index]
          segments << create_static_segment(static_text, current_position) unless static_text.strip.empty?
        end

        # Add the token segment. l1_end_index is inclusive (see
        # TokenTranslation#original_text), so slice with `..` and advance the
        # cursor past the token — otherwise the token's last character leaks
        # into the following static segment.
        token_text = phrase.text_l1[token.l1_start_index..token.l1_end_index]
        segments << create_token_segment(token, token_text)

        current_position = token.l1_end_index + 1
      end

      # Add any remaining static text after the last token
      if current_position < text_length
        static_text = phrase.text_l1[current_position...text_length]
        segments << create_static_segment(static_text, current_position) unless static_text.strip.empty?
      end

      segments
    end

    def create_static_segment(text, position)
      {
        type: "static",
        text: text,
        position: position
      }
    end

    def create_token_segment(token, text)
      {
        type: "token",
        text: text,
        token_id: token.id,
        position: token.l1_start_character_index,
        audio_url: token.l1_audio_url
      }
    end

    def fallback_word_segments(text)
      # Fallback to word splitting when no token translations exist
      words = text.split(/\s+/)
      words.map.with_index do |word, index|
        {
          type: "token",
          text: word,
          token_id: "fallback-#{index}",
          position: index,
          audio_url: nil
        }
      end
    end
  end
end
