class PhraseText < ApplicationRecord
  belongs_to :script
  has_many :phrase_text_assignments, dependent: :destroy
  has_many :phrases, through: :phrase_text_assignments
  
  validates :content, presence: true
end