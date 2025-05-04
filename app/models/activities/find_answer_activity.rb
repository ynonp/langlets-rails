module Activities
  class FindAnswerActivity < Activity
    def activity_params
      {
        text: phrases.map { |p| {id: p.id, text: p.text_l1} },
        questions: phrases.includes(:token_translations).map do |p|
          token_translations = p.token_translations.where("questions is not null and cardinality(questions) > 0")
          {
            phrase_id: p.id,
            questions: token_translations.map do |t|
              {
                id: t.id,
                question: t.questions[0],
                answer_start: t.start_index,
                answer_end: t.end_index
              }
            end
          }
        end,
      }
    end
  end
end
