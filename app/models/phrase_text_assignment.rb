class PhraseTextAssignment < ApplicationRecord
  belongs_to :phrase
  belongs_to :phrase_text
  
  enum :language_role, { l1: 1, l2: 2 }
  
  validates :phrase_id, uniqueness: { scope: [:language_role, :primary], 
                                     conditions: -> { where(primary: true) } }
end