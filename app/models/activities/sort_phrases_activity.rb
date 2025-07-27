module Activities
  class SortPhrasesActivity < Activity
    def activity_params
      {        
        **video_params,
        phrases_for_sorting: ordered_phrases.first(4),  # Pass phrases objects instead of text
        l1: cached_l1_language&.iso_name,
      }
    end

    private

    def cached_l1_language
      @cached_l1_language ||= ordered_phrases.first&.l1
    end
  end
end
