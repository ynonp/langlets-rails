module Activities
  class LanguageAlignmentActivity < Activity
    def activity_params
      activity_translations = Set.new(phrase_tokens.ids)
      # Preload Active Storage attachments to prevent N+1 queries
      preloaded_phrases = phrases.ordered_by_timestamp.includes(
        :localized_translation,
        phrase_tokens: [ :localized_translation, { l1_audio_attachment: :blob } ]
      )
      
      {
        **video_params,
        rtl: phrases.first.l1.rtl,
        phrases_with_tokens: preloaded_phrases.map do |p|
          {
            phrase: p,  # Pass the phrase object instead of extracting text
            tokens: p.phrase_tokens.filter_map do |t|
              {
                l1_start_index: t.l1_start_index,
                l1_end_index: t.l1_end_index,
                l2_start_index: t.l2_start_index, 
                l2_end_index: t.l2_end_index,
                audio_url: t.l1_audio_url,
              } if activity_translations.include?(t.id)
            end
          }
        end,
        l1: phrases.first.l1.english_name,
        l2: phrases.first.l2.english_name,
      }
    end
  end
end
