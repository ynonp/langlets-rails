module Activities
  class MatchPhrasesActivity < Activity    
    def activity_params
      phrases_array = phrases.to_a
      phrases_data_for_activity = phrases_array.zip(phrases_array[1..]).map {|p, np| 
        [p.text_l1, p.text_l2, p.timestamp, np&.timestamp || to_string_timestamp(p.timestamp_seconds + 5)]
      }

      {
        **video_params,
        phrases: phrases_data_for_activity,
        l1: phrases.first.l1,
        l2: phrases.first.l2
      }
    end
  end
end
