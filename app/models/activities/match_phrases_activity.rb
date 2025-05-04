module Activities
  class MatchPhrasesActivity < Activity
    def activity_params
      {
        phrases: phrases.map do |p|
          [ p.text_l1, p.text_l2 ]
        end,
        l1: phrases.first.l1.iso_name,
        l2: phrases.first.l2.iso_name,
      }
    end
  end
end
