module Activities
  class WatchVideoActivity < Activity
    include ActivityWithTokens

    def activity_params
      first_phrase = ordered_phrases.first
      l1 = first_phrase&.l1
      l2 = first_phrase&.l2

      {
        **video_params,
        phrases: ordered_phrases,
        video_player: true,
        l1_rtl: l1&.rtl,
        l2_rtl: l2&.rtl
      }
    end

  end
end
