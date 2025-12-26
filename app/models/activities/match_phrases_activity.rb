module Activities
  class MatchPhrasesActivity < Activity
    include ActivityWithTokens

    def activity_params
      {
        **video_params,
        phrases: phrases_with_calculated_end_timestamps.shuffle,
        all_l2_phrases: lesson.medium.phrases.to_a,
        l1: phrases.first.l1,
        l2: phrases.first.l2
      }
    end
  end
end
