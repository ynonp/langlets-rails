module Activities
  class LanguageAlignmentActivity < Activity
    def activity_params
      activity_translations = Set.new(token_translations.ids)
      
      {
        **video_params,
        rtl: cached_l1_language&.rtl,
        phrases_with_tokens: ordered_phrases.map do |p|
          {
            phrase: p,  # Pass the phrase object instead of extracting text
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
        l1: cached_l1_language&.english_name,
        l2: cached_l2_language&.english_name,
      }
    end

    private

    def cached_l1_language
      @cached_l1_language ||= ordered_phrases.first&.l1
    end

    def cached_l2_language
      @cached_l2_language ||= ordered_phrases.first&.l2
    end
  end
end
