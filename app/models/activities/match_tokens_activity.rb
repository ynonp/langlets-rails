module Activities
  class MatchTokensActivity < Activity
    def activity_params
      # Just return basic info - script-dependent data will be prepared in the view
      activity_phrase_tokens = phrase_tokens.includes(:localized_translation, phrase: [ :l1, :localized_translation ], l1_audio_attachment: :blob).to_a
      
      {
        phrase_tokens: activity_phrase_tokens,
        l1: activity_phrase_tokens.first&.phrase&.l1,
        l2: activity_phrase_tokens.first&.phrase&.l2
      }
    end
  end
end
