class TokenTranslation < ApplicationRecord
  belongs_to :phrase
  scope :with_questions, ->() {
    where("questions is not null and cardinality(questions) > 0")
  }
end
