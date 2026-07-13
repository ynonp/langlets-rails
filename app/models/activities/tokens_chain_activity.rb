module Activities
  class TokensChainActivity < Activity
    include ActivityWithTokens

    def activity_params
      activity_token_translations = token_translations
        .includes(phrase: [:l1, :l2], l1_audio_attachment: :blob)
        .to_a
        .first(15)
        .shuffle # Randomize chain order

      # Build token data array with L1 text, L2 translation, ID, and audio URL
      tokens_data = activity_token_translations.map do |token|
        {
          id: token.id,
          l1_text: token.original_text,
          l2_text: token.translation,
          audio_url: token.l1_audio_url
        }
      end

      {
        tokens: tokens_data,
        l1: activity_token_translations.first&.phrase&.l1,
        l2: activity_token_translations.first&.phrase&.l2
      }
    end
  end
end

