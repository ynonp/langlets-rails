module Activities
  class LanguageAlignmentActivity < Activity
    def activity_params
      activity_translations = Set.new(token_translations.ids)
      # Preload Active Storage attachments to prevent N+1 queries
      preloaded_phrases = phrases.ordered_by_timestamp.includes(
        token_translations: { l1_audio_attachment: :blob }
      )
      
      {
        **video_params,
        rtl: phrases.first.l1.rtl,
        phrases: preloaded_phrases.map do |p|
          {
            text: p.text_l1,
            translation: p.text_l2,
            tokens: p.token_translations.filter_map do |t|
              {
                l1_start_index: t.l1_start_index,
                l1_end_index: t.l1_end_index,
                l2_start_index: t.l2_start_index,
                l2_end_index: t.l2_end_index,
                audio_url: t.l1_audio.present? ? Rails.application.routes.url_helpers.rails_blob_path(t.l1_audio, only_path: true) : nil,
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
