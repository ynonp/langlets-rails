class Script < ApplicationRecord
  has_many :phrase_texts, dependent: :restrict_with_error
  has_many :languages, foreign_key: :default_script_id, dependent: :restrict_with_error
  
  validates :name, presence: true, uniqueness: true
end