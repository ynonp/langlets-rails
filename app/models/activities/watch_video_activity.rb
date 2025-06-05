module Activities
  class WatchVideoActivity < Activity
    def activity_params
      lesson = self.lesson
      {
        **video_params,
        phrases: phrases.ordered_by_timestamp.includes(:token_translations)
      }
    end
  end
end
