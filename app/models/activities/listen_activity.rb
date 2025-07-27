module Activities
  class ListenActivity < Activity
    def activity_params
      {
        **video_params,
        rtl: cached_l1_language&.rtl,
        phrases: ordered_phrases,
      }
    end

    private

    def cached_l1_language
      @cached_l1_language ||= ordered_phrases.first&.l1
    end
  end
end
