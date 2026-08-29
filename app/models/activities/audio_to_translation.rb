module Activities
  class AudioToTranslation < Activity
    include ActivityWithMediaPlayback

    def activity_params
      {
        **video_params,
        video_player: false,
        preload_player: true,
        phrases: phrases_with_playback_boundaries,
        l1: ordered_phrases.first.l1,
        l2: ordered_phrases.first.l2
      }
    end
  end
end
