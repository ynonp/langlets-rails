module Activities
  class MatchPhrasesActivity < Activity
    include ActivityWithMediaPlayback

    def activity_params
      {
        **video_params,
        phrases: phrases_with_playback_boundaries.shuffle,
        all_l2_phrases: lesson.medium.phrases.includes(:localized_translation).to_a,
        l1: ordered_phrases.first.l1,
        l2: ordered_phrases.first.l2
      }
    end
  end
end
