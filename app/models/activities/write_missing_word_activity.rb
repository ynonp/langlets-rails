module Activities
  class WriteMissingWordActivity < Activity
    def activity_params
      activity_token_translations = token_translations
        .includes(phrase: [:l1, :l2], l1_audio_attachment: :blob)
        .to_a

      cards = activity_token_translations.map do |token|
        words = token.phrase.text_l1.split
        answer = words[token.l1_start_index..token.l1_end_index].join(" ")

        # Build sentence with the token replaced by underscores
        blanked = words.each_with_index.map do |word, idx|
          if idx >= token.l1_start_index && idx <= token.l1_end_index
            nil
          else
            word
          end
        end.compact

        blank_placeholder = "_" * [answer.length, 5].max

        sentence_parts = words.each_with_index.each_with_object({ before: [], after: [] }) do |(word, idx), parts|
          if idx < token.l1_start_index
            parts[:before] << word
          elsif idx > token.l1_end_index
            parts[:after] << word
          end
        end

        phrase_with_blank = [
          sentence_parts[:before].join(" "),
          blank_placeholder,
          sentence_parts[:after].join(" ")
        ].reject(&:blank?).join(" ")

        {
          id: token.id,
          phrase_with_blank: phrase_with_blank,
          answer: answer,
          translation: token.translation,
          audio_url: token.l1_audio.attached? ?
            Rails.application.routes.url_helpers.rails_blob_path(token.l1_audio, only_path: true) : nil
        }
      end

      {
        cards: cards,
        l1: activity_token_translations.first&.phrase&.l1,
        l2: activity_token_translations.first&.phrase&.l2
      }
    end
  end
end
