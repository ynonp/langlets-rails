module Activities
  class MatchTokensActivity < Activity
    def activity_params
      # Fetch activity's token translations with phrases preloaded to avoid N+1 queries
      activity_token_translations = token_translations.includes(:phrase, l1_audio_attachment: :blob).to_a
      
      # Map each token translation to [word in l1, translation in l2, audio]
      tokens_data = activity_token_translations.map do |t|
        l1_word = t.phrase.text_l1[t.l1_start_index..t.l1_end_index]
        audio_url = t.l1_audio.attached? ? 
          Rails.application.routes.url_helpers.rails_blob_path(t.l1_audio, only_path: true) : nil
        
        {
          l1_word: l1_word,
          l2_translation: t.translation,
          audio_url: audio_url,
          id: t.id
        }
      end

      {
        **video_params,
        tokens: tokens_data,
        l1: token_translations.first.phrase.l1,
        l2: token_translations.first.phrase.l2
      }
    end
  end
end
