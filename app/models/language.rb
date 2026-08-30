class Language < ApplicationRecord
  belongs_to :default_script, class_name: 'Script', optional: true
  has_many :courses, dependent: :destroy
  has_many :phrases_as_l1, class_name: 'Phrase', foreign_key: 'l1_id', dependent: :destroy
  has_many :phrase_tokens, class_name: 'PhraseTranslation', foreign_key: 'language_id', dependent: :destroy
end
