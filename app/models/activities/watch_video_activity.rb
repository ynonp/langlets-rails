module Activities
  class WatchVideoActivity < Activity
    include ActivityWithTokens

    def activity_params
      lesson = self.lesson
      l2 = ordered_phrases.first.l2

      {
        **video_params,
        phrases: ordered_phrases,
        video_player: true,
        interactive_video_player: true,
        preload_player: true,
        word_timing: word_timing_enabled?(ordered_phrases),
        l1_rtl: lesson.rtl_language,
        l2_rtl: l2.rtl,
        l1_name: lesson.media_language,
      }
    end

    private

    # Karaoke word highlighting is available only when this lesson's tokens carry
    # per-word timestamps (new pipeline). Older songs fall back to line highlight.
    def word_timing_enabled?(phrases)
      phrases.any? { |phrase| phrase.phrase_tokens.any? { |t| t.start_timestamp.present? } }
    end

  end
end
