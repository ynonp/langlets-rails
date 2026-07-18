class PhraseToken < ApplicationRecord
  include AzureTextToSpeech
  include WordToCharIndex

  belongs_to :phrase
  has_many :token_translations, dependent: :destroy, inverse_of: :phrase_token
  has_one :localized_translation,
          -> { where(language_id: Current.translation_language_id) },
          class_name: "TokenTranslation"
  has_many :phrase_token_users, dependent: :destroy
  has_one_attached :l1_audio, service: :s3_public

  attribute :index_type, :integer
  enum :index_type, { word_index: 0, character_index: 1 }, default: :word_index
  has_timestamp [ :start_timestamp, :end_timestamp ]

  validate :validate_l1_indexes

  scope :with_questions, -> { where("questions is not null and cardinality(questions) > 0") }

  attr_accessor :resolved_translation

  def translation = resolved_translation&.translation || localized_translation&.translation
  def l2_start_index = resolved_translation&.l2_start_index || localized_translation&.l2_start_index
  def l2_end_index = resolved_translation&.l2_end_index || localized_translation&.l2_end_index

  def karaoke? = start_timestamp.present?

  def l1_audio_url
    l1_audio.attached? ? l1_audio.url : nil
  end

  def l1_start_character_index
    character_index? ? self[:l1_start_index] : word_to_char_index(phrase&.text_l1, self[:l1_start_index])
  end

  def l1_end_character_index
    character_index? ? self[:l1_end_index] : word_to_char_index(phrase&.text_l1, self[:l1_end_index], inclusive: true)
  end

  def l1_start_index = l1_start_character_index
  def l1_end_index = l1_end_character_index
  def original_text = phrase&.text_l1.to_s[l1_start_character_index..l1_end_character_index].to_s
  def span_length = l1_end_character_index - l1_start_character_index

  after_create :generate_l1_audio, if: :should_generate_audio?
  after_update :generate_l1_audio, if: :should_generate_audio_on_update?

  private

  def validate_l1_indexes
    return if phrase&.text_l1.blank?

    start_index = self[:l1_start_index]
    end_index = self[:l1_end_index]
    if start_index.nil? || end_index.nil?
      errors.add(:l1_start_index, "l1 indexes are required (phrase text #{phrase.text_l1})")
      return
    end
    errors.add(:l1_start_index, "must be less than or equal to l1_end_index") if start_index > end_index

    upper_bound = character_index? ? phrase.text_l1.length : phrase.text_l1.split.length
    if start_index.negative? || end_index >= upper_bound
      errors.add(:l1_start_index, "indexes #{start_index}-#{end_index} out of bounds for phrase #{phrase.text_l1}")
    end
  end

  def should_generate_audio?
    original_text.present? && phrase&.l1&.iso_name.present?
  end

  def should_generate_audio_on_update?
    (saved_change_to_l1_start_index? || saved_change_to_l1_end_index?) && should_generate_audio?
  end

  def generate_l1_audio
    GenerateTokenAudioJob.perform_later(id) unless Rails.env.development?
  end

end
