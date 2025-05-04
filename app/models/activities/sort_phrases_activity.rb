module Activities
  class SortPhrasesActivity < Activity
    def activity_params
      {        
        **video_params,
        phrases: phrases.map { |p| p.text_l1 },
        l1: phrases.first.l1.iso_name,
      }
    end
  end
end
