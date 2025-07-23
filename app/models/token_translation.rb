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

  def original_text
    phrase.text_l1.tokenize[l1_start_index..l1_end_index].join(" ")
  end

  private

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
