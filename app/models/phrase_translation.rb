class PhraseTranslation < ApplicationRecord
  belongs_to :phrase, inverse_of: :phrase_translations
  belongs_to :language

  validates :text, presence: true
  validates :language_id, uniqueness: { scope: :phrase_id }
end
