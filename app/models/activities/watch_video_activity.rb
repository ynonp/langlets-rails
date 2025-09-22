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
        l1_rtl: lesson.rtl_language,
        l2_rtl: l2.rtl,
        l1_name: lesson.media_language,
      }
    end

  end
end
