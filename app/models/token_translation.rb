class TokenTranslation < ApplicationRecord
  include AzureTextToSpeech
  
  belongs_to :phrase
  has_one_attached :l1_audio, service: :s3_public

  # Generate audio when token is created
  after_create :generate_l1_audio, if: :should_generate_audio?
  
  # Regenerate audio when indices change (affecting the original_text)
  after_update :generate_l1_audio, if: :should_generate_audio_on_update?

  # Validation for word indexes
  validate :validate_word_indexes

  scope :with_questions, ->() {
    where("questions is not null and cardinality(questions) > 0")
  }

  def original_text
    l1_words = phrase.text_l1.words
    @original_text ||= phrase.text_l1.to_s[l1_characters_range]
  end

  def l1_characters_range(script = nil)
    phrase.text_l1.character_range(l1_start_index, l1_end_index, script:)
  end

  def l2_characters_range(script = nil)
    phrase.text_l2.character_range(l2_start_index, l2_end_index, script:)
  end

  private

  def should_generate_audio?
    original_text.present? && phrase&.l1&.iso_name.present?
  end

  def should_generate_audio_on_update?
    # Generate audio if indices changed (which affects original_text) and we have the necessary data
    (saved_change_to_l1_start_index? || saved_change_to_l1_end_index?) && should_generate_audio?
  end

  def generate_l1_audio
    # Queue background job for audio generation
    GenerateTokenAudioJob.perform_later(id)
  end

  def validate_word_indexes
    return unless phrase&.text_l1

    # Get the words for the phrase
    l1_words = phrase.text_l1.words
    
    # Validate L1 indexes
    if l1_start_index.present? && l1_end_index.present?
      if l1_start_index > l1_end_index
        errors.add(:l1_start_index, "must be less than or equal to l1_end_index")
      end

      if l1_start_index < 0 || l1_end_index >= l1_words.length
        errors.add(:l1_start_index, "word indexes out of bounds")
      end
    else
      errors.add(:l1_start_index, "l1 start index is required")
    end

    # Validate L2 indexes (optional)
    if l2_start_index.present? && l2_end_index.present? && phrase&.text_l2
      l2_words = phrase.text_l2.words
      
      if l2_start_index > l2_end_index
        errors.add(:l2_start_index, "must be less than or equal to l2_end_index")
      end

      if l2_start_index < 0 || l2_end_index >= l2_words.length
        errors.add(:l2_start_index, "word indexes out of bounds")
      end
    end
  end
end
