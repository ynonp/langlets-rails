class TokenTranslation < ApplicationRecord
  belongs_to :phrase
  has_one_attached :l1_audio

  scope :with_questions, ->() {
    where("questions is not null and cardinality(questions) > 0")
  }

  def original_text
    phrase.text_l1[l1_start_index...l1_end_index]
  end
end
