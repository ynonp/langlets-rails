require 'set'

module Activities
  class MatchTokensActivity < Activity
    def activity_params
      # Fetch activity's token translations with phrases and their languages preloaded to avoid N+1 queries
      activity_token_translations = token_translations.includes(phrase: [:l1, :l2], l1_audio_attachment: :blob).to_a
    
    # Filter out duplicates based on l1 text value or l2 text value
    seen_l1_texts = Set.new
    seen_l2_texts = Set.new
    filtered_token_translations = activity_token_translations.select do |t|
      l1_text = t.phrase.text_l1[t.l1_start_index..t.l1_end_index]
      l2_text = t.translation
      
      # Skip if we've already seen this l1 or l2 text
      if seen_l1_texts.include?(l1_text) || seen_l2_texts.include?(l2_text)
        false
      else
        seen_l1_texts.add(l1_text)
        seen_l2_texts.add(l2_text)
        true
      end
    end
    
    # Map each token translation to [word in l1, translation in l2, audio]
    tokens_data = filtered_token_translations.map do |t|
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
        l1: filtered_token_translations.first&.phrase&.l1,
        l2: filtered_token_translations.first&.phrase&.l2
      }
    end
  end
end
