module Activities
  class SortPhrasesActivity < Activity
    def activity_params
      {        
        **video_params,
        phrases_for_sorting: phrases.ordered_by_timestamp.first(4),  # Pass phrases objects instead of text
        l1: phrases.first.l1.iso_name,
      }
    end
  end
end
