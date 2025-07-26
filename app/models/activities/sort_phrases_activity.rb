module Activities
  class SortPhrasesActivity < Activity
    def activity_params(current_script: nil)
      # Get phrases and use script-aware text extraction
      phrase_texts = phrases.ordered_by_timestamp.first(4).map do |p|
        current_script ? p.text_l1.to_s(current_script) : p.text_l1.to_s
      end
      
      {        
        **video_params,
        phrases: phrase_texts,
        l1: phrases.first.l1.iso_name,
      }
    end
  end
end
