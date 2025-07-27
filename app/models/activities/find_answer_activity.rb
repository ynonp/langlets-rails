module Activities
  class FindAnswerActivity < Activity
    def activity_params
      {
        phrases: ordered_phrases,
        text: ordered_phrases.map { |p| {id: p.id, text: p.text_l1, translation: p.text_l2} },
        questions: ordered_phrases.map do |p|
          token = p.token_translations.with_questions.sample
          {
            phrase_id: p.id,
            question: token.questions[0],
            answer_token_id: token.id,
          }
        end,
      }
    end
  end
end
