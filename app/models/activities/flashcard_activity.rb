module Activities
  class FlashcardActivity < Activity
    def activity_params
      activity_token_translations = token_translations.includes(phrase: [:l1, :l2], l1_audio_attachment: :blob).to_a

      {
        token_translations: activity_token_translations,
        l1: activity_token_translations.first&.phrase&.l1,
        l2: activity_token_translations.first&.phrase&.l2,
        unique_words: lesson.medium.phrases.flat_map {|p| p.text_l1.tokenize.map(&:to_s) }.uniq
      }
    end
  end
end
