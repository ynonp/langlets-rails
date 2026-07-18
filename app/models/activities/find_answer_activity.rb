module Activities
  class FindAnswerActivity < Activity
    def activity_params
      {
        phrases: phrases.ordered_by_timestamp.includes(:localized_translation, :phrase_tokens),
        text: phrases.ordered_by_timestamp.map { |p| {id: p.id, text: p.text_l1, translation: p.text_l2} },
        questions: phrases.includes(:localized_translation, :phrase_tokens).ordered_by_timestamp.map do |p|
          token = p.phrase_tokens.with_questions.sample
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
