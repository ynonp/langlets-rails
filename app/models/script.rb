class Script < ApplicationRecord
  has_many :phrase_texts, dependent: :restrict_with_error
  
  validates :name, presence: true, uniqueness: true
  validates :iso_code, presence: true, allow_blank: true
end