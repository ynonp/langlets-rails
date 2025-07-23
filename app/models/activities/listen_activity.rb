module Activities
  class ListenActivity < Activity
    def activity_params
      activity_translations = Set.new(token_translations.ids)
      {
        **video_params,
        rtl: phrases.first.l1.rtl,
        phrases: phrases.ordered_by_timestamp.includes(:token_translations).map do |p|
          {
            "text_l1" => p.text_l1,
            "text_l2" => p.text_l2,
            "timestamp" => p.timestamp,
            "token_translations" => p.token_translations.filter_map do |t|
              {
                "start_index" => t.l1_start_index,
                "end_index" => t.l1_end_index,
                "original_text" => t.original_text,
                "similar_sound" => (t.similar_sound || []).sample
              } if activity_translations.include?(t.id)
            end
          }
        end
      }
    end
  end
end 
