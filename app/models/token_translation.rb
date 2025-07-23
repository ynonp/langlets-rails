class TokenTranslation < ApplicationRecord
  include AzureTextToSpeech
  
  belongs_to :phrase
  has_one_attached :l1_audio, service: :s3_public

  # Generate audio when token is created
  after_create :generate_l1_audio, if: :should_generate_audio?
  
  # Regenerate audio when indices change (affecting the original_text)
  after_update :generate_l1_audio, if: :should_generate_audio_on_update?

  scope :with_questions, ->() {
    where("questions is not null and cardinality(questions) > 0")
  }

  # NEW: Validation for continuous word indexes
  validate :validate_continuous_word_indexes

  # NEW: Extract original text using word indexes
  def original_text
    l1_words = tokenize(phrase.text_l1)
    return "" if l1_start_index.nil? || l1_end_index.nil?
    return "" if l1_start_index < 0 || l1_end_index >= l1_words.length
    return "" if l1_start_index > l1_end_index

    l1_words[l1_start_index..l1_end_index].join(' ')
  end

  # NEW: Extract L2 text using word indexes
  def translation_text
    return translation if l2_start_index.nil? || l2_end_index.nil?
    
    l2_words = tokenize(phrase.text_l2)
    return translation if l2_start_index < 0 || l2_end_index >= l2_words.length
    return translation if l2_start_index > l2_end_index

    l2_words[l2_start_index..l2_end_index].join(' ')
  end

  private

  def tokenize(text)
    text.scan(/\p{L}+(?:'\p{L}+)*/u)
  end

  def validate_continuous_word_indexes
    # Validate L1 indexes
    if l1_start_index.present? && l1_end_index.present?
      if l1_start_index > l1_end_index
        errors.add(:l1_start_index, "must be less than or equal to l1_end_index")
      end

      l1_words = tokenize(phrase.text_l1)
      if l1_start_index < 0 || l1_end_index >= l1_words.length
        errors.add(:l1_start_index, "word indexes out of bounds")
      end
    end

    # Validate L2 indexes (optional)
    if l2_start_index.present? && l2_end_index.present?
      if l2_start_index > l2_end_index
        errors.add(:l2_start_index, "must be less than or equal to l2_end_index")
      end

      l2_words = tokenize(phrase.text_l2)
      if l2_start_index < 0 || l2_end_index >= l2_words.length
        errors.add(:l2_start_index, "word indexes out of bounds")
      end
    end
  end

  def should_generate_audio?
    # Generate audio if we have text and a language
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
end
