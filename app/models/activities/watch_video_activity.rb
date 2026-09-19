module Activities
  class WatchVideoActivity < Activity
    def activity_params
      lesson = self.lesson
      l1 = ordered_phrases.first.l1
      l2 = ordered_phrases.first.l2

      {
        **video_params,
        phrases: ordered_phrases,
        video_player: true,
        interactive_video_player: true,
        preload_player: true,
        word_timing: word_timing_enabled?(ordered_phrases),
        sentence_ends: sentence_end_timestamps(ordered_phrases),
        l1: l1,
        l2: l2,
        l1_rtl: lesson.rtl_language,
        l2_rtl: l2.rtl
      }
    end

    private

    # Karaoke word highlighting is available only when this lesson's tokens carry
    # per-word timestamps (new pipeline). Older songs fall back to line highlight.
    def word_timing_enabled?(phrases)
      phrases.any? { |phrase| phrase.phrase_tokens.any? { |t| t.start_timestamp.present? } }
    end

    # Timed courses pause after the sentence's last spoken word. Older courses
    # fall back to the following sentence's start. The segment boundary already
    # handles the final sentence, so it is intentionally omitted here.
    def sentence_end_timestamps(phrases)
      phrases.each_with_index.filter_map do |phrase, index|
        next if index == phrases.length - 1

        token_end = phrase.phrase_tokens.filter_map(&:end_timestamp).max_by do |timestamp|
          Phrase.timestamp_to_seconds(timestamp)
        end
        end_timestamp = token_end || phrases[index + 1].timestamp

        [ phrase.id, Phrase.timestamp_to_seconds(end_timestamp) ]
      end.to_h
    end

  end
end
