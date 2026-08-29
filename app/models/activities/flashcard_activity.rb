module Activities
  class FlashcardActivity < Activity
    def activity_params
      activity_phrase_tokens = phrase_tokens.includes(
        :localized_translation,
        { l1_audio_attachment: :blob },
        phrase: [ :l1, :localized_translation, :medium, :phrase_tokens ]
      ).to_a

    {
        phrase_tokens: activity_phrase_tokens,
        video_player: true,
        interactive_video_player: true,
        l1: activity_phrase_tokens.first&.phrase&.l1,
        l2: activity_phrase_tokens.first&.phrase&.l2,
        unique_words: if lesson.medium
          lesson.medium.phrases.flat_map {|p| p.text_l1.tokenize.map(&:to_s) }.uniq
        else
          activity_phrase_tokens.flat_map { |token| token.phrase.text_l1.tokenize.map(&:to_s) }.uniq
        end
      }
    end
  end
end
