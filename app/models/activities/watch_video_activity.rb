module Activities
  class WatchVideoActivity < Activity
    def activity_params
      lesson = self.lesson
      l1 = ordered_phrases.first.l1
      l2 = ordered_phrases.first.l2

      {
        **video_params,
        phrases: ordered_phrases,
        l1_rtl: l1.rtl,
        l2_rtl: l2.rtl,
      }
    end

    def ordered_phrases
      @ordered_phrases ||= phrases.ordered_by_timestamp.includes(token_translations: { l1_audio_attachment: :blob }).to_a
    end
  end
end
