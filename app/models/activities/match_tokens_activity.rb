module Activities
  class MatchTokensActivity < Activity
    def activity_params
      # Use preloaded token_translations from the controller
      activity_token_translations = token_translations.includes(phrase: [:l1, :l2], l1_audio_attachment: :blob).to_a
      
      {
        token_translations: activity_token_translations,
        l1: activity_token_translations.first&.phrase&.l1,
        l2: activity_token_translations.first&.phrase&.l2
      }
    end
  end
end
