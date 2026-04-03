module Activities
  class WriteMissingWordActivity < Activity
    def activity_params
      activity_token_translations = token_translations
        .includes(phrase: [ :l1, :l2 ], l1_audio_attachment: :blob)
        .to_a

      cards = activity_token_translations.map do |token|
        text = token.phrase.text_l1
        start_idx = token.l1_start_index
        end_idx = token.l1_end_index

        next nil if start_idx.nil? || end_idx.nil?

        answer = text[start_idx..end_idx]
        next nil if answer.nil? || answer.blank?

        blank_placeholder = "_" * [ answer.length, 5 ].max
        phrase_with_blank = text[0...start_idx] + blank_placeholder + text[(end_idx + 1)..]

        {
          id: token.id,
          phrase_with_blank: phrase_with_blank,
          answer: answer,
          translation: token.translation,
          audio_url: token.l1_audio.attached? ?
            Rails.application.routes.url_helpers.rails_blob_path(token.l1_audio, only_path: true) : nil
        }
      end.compact

      all_answers = cards.map { |c| c[:answer] }
      cards = cards.map do |card|
        distractors = (all_answers - [ card[:answer] ]).sample(3)
        card.merge(options: ([ card[:answer] ] + distractors).shuffle)
      end

      {
        cards: cards,
        l1: activity_token_translations.first&.phrase&.l1,
        l2: activity_token_translations.first&.phrase&.l2
      }
    end
  end
end
