class SimilarSound < ApplicationRecord
  belongs_to :phrase

  validates :start_word_index, :end_word_index,
            presence: true
  validates :replacement_text, presence: true
end
