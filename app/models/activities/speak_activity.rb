module Activities
  class SpeakActivity < Activity
    def activity_params
      lesson = self.lesson
      phrase = phrases.sample
      {
        **video_params,
        l1: phrase.l1.english_name,
        l2: phrase.l2.english_name,
        phrases: phrases.where(id: phrase.id).includes(:token_translations),
      }
    end
  end
end
