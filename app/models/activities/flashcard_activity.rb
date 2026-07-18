module Activities
  class FlashcardActivity < Activity
    def activity_params
      activity_phrase_tokens = phrase_tokens.includes(:localized_translation, phrase: [ :l1, :localized_translation ], l1_audio_attachment: :blob).to_a

    {
        phrase_tokens: activity_phrase_tokens,
        l1: activity_phrase_tokens.first&.phrase&.l1,
        l2: activity_phrase_tokens.first&.phrase&.l2,
        unique_words: if lesson.medium
          lesson.medium.phrases.flat_map {|p| p.text_l1.tokenize.map(&:to_s) }.uniq
        else
          activity_phrase_tokens.map(&:original_text).uniq
        end
      }
    end
  end
end
