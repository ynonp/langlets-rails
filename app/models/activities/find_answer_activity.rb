module Activities
  class FindAnswerActivity < Activity
    def activity_params
      {
        text: phrases.map { |p| {id: p.id, text: p.text_l1, translation: p.text_l2} },
        questions: phrases.includes(:token_translations).map do |p|
          token_translations = p.token_translations.with_questions
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
