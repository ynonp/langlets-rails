class PhraseTokenUser < ApplicationRecord
  belongs_to :user
  belongs_to :phrase_token
  belongs_to :language
  before_validation :pin_available_language, on: :create

  validates :phrase_token_id, uniqueness: { scope: :user_id }

  def token_translation
    phrase_token.token_translations.find { |row| row.language_id == language_id } ||
      phrase_token.token_translations.find_by(language_id: language_id)
  end

  private

  def pin_available_language
    self.language ||= Current.translation_language || phrase_token&.token_translations&.first&.language
  end
end
