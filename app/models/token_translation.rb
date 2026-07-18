class TokenTranslation < ApplicationRecord
  include WordToCharIndex

  belongs_to :phrase_token, inverse_of: :token_translations
  belongs_to :language

  validates :translation, presence: true
  validates :language_id, uniqueness: { scope: :phrase_token_id }
  validate :validate_l2_indexes

  delegate :phrase, :original_text, to: :phrase_token

  def l2_start_index = character_index(self[:l2_start_index])
  def l2_end_index = character_index(self[:l2_end_index], inclusive: true)

  private

  def character_index(index, inclusive: false)
    return nil if index.nil?
    return index if phrase_token.character_index?

    word_to_char_index(phrase_translation_text, index, inclusive: inclusive)
  end

  def phrase_translation_text
    phrase.phrase_translations.find { |row| row.language_id == language_id }&.text ||
      phrase.phrase_translations.find_by(language_id: language_id)&.text
  end

  def validate_l2_indexes
    start_index = self[:l2_start_index]
    end_index = self[:l2_end_index]
    return if start_index.nil? && end_index.nil?

    if start_index.nil? || end_index.nil?
      errors.add(:l2_start_index, "both L2 indexes are required")
      return
    end
    errors.add(:l2_start_index, "must be less than or equal to l2_end_index") if start_index > end_index
    text = phrase_translation_text
    return if text.blank?

    upper_bound = phrase_token.character_index? ? text.length : text.split.length
    errors.add(:l2_start_index, "indexes are outside the phrase translation") if start_index.negative? || end_index >= upper_bound
  end
end
