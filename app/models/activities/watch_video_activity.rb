module Activities
  class WatchVideoActivity < Activity
    def activity_params
      lesson = self.lesson
      {
        **video_params,
        phrases: phrases.ordered_by_timestamp.includes(:token_translations),
        texts: phrases.ordered_by_timestamp.includes(:token_translations).map do |p|
          {
            "text_l1" => p.text_l1,
            "text_l2" => p.text_l2,
            "timestamp" => p.timestamp,
            "token_translations" => p.token_translations.map do |t|
              {
                "start_index" => t.l1_start_index,
                "end_index" => t.l1_end_index,
                "translation" => t.translation,
                "questions" => t.questions
              }
            end
          }
        end
      }
    end
  end
end
