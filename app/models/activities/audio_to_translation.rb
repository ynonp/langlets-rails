module Activities
  class AudioToTranslation < Activity
    include ActivityWithTokens

    def activity_params
      {
        **video_params,
        video_player: false,
        preload_player: true,
        phrases: phrases_with_calculated_end_timestamps,
        l1: phrases.first.l1,
        l2: phrases.first.l2
      }
    end
  end
end
