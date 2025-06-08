module Activities
  class WordOrderActivity < Activity
    def activity_params
      phrases_data_for_activity = ordered_phrases.zip(ordered_phrases[1..]).map {|p, np| 
        [
          p.text_l2,
          p.text_l1,
          p.timestamp,
          np&.timestamp || to_string_timestamp(p.timestamp_seconds + 5),
        ]
      }

      {
        **video_params,
        phrases: phrases_data_for_activity,
        l1: phrases.first.l1,
        l2: phrases.first.l2,
      }
    end
  end
end
