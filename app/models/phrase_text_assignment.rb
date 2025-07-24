class PhraseTextAssignment < ApplicationRecord
  belongs_to :phrase
  belongs_to :phrase_text
  
  enum :language_role, { l1: 1, l2: 2 }
  
  validates :phrase_id, uniqueness: { 
    scope: [:language_role, :primary], 
    conditions: -> { where(primary: true) },
    message: "can only have one primary text per language role"
  }
  
  # Ensure boolean primary field defaults correctly
  validates :primary, inclusion: { in: [true, false] }
end