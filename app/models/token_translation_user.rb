class TokenTranslationUser < ApplicationRecord
  belongs_to :user
  belongs_to :token_translation

  validates :token_translation_id, uniqueness: { scope: :user_id }
end
