module Activities
  class ReadTranslatedActivity < Activity
    def activity_params
      l2 = ordered_phrases.first.l2

      {
        phrases: ordered_phrases,
        l2_rtl: l2.rtl,
      }
    end
  end
end
