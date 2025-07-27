module Activities
  class FindAnswerActivity < Activity
    def activity_params
      {
        phrases: phrases.ordered_by_timestamp.includes(:text_l1 => :script_variants, :token_translations => []),
        text: phrases.ordered_by_timestamp.includes(:text_l1 => :script_variants, :text_l2 => :script_variants).map { |p| {id: p.id, text: p.text_l1, translation: p.text_l2} },
        questions: phrases.includes(:text_l1 => :script_variants, :text_l2 => :script_variants, :token_translations => []).ordered_by_timestamp.map do |p|
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
