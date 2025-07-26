module Activities
  class WatchVideoActivity < Activity
    include ActivityWithTokens

    def activity_params(current_script: nil)
      lesson = self.lesson
      l1 = ordered_phrases.first.l1
      l2 = ordered_phrases.first.l2

      {
        **video_params,
        phrases: ordered_phrases,
        video_player: true,
        l1_rtl: l1.rtl,
        l2_rtl: l2.rtl
      }
    end

  end
end
