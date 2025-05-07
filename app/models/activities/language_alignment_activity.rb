module Activities
  class LanguageAlignmentActivity < Activity
    def activity_params
      {
        **video_params,
        phrases: phrases.map do |p|
          {
            text: p.text_l1,
            translation: p.text_l2,
            tokens: p.token_translations.map do |t|
              {
                l1_start_index: t.l1_start_index,
                l1_end_index: t.l1_end_index,
                l2_start_index: t.l2_start_index,
                l2_end_index: t.l2_end_index,                
              }
            end
          }
        end,
        l1: phrases.first.l1.iso_name,
        l2: phrases.first.l2.iso_name,
      }
    end
  end
end
