class Phrase < ApplicationRecord
  include AzureTextToSpeech
  
  belongs_to :medium
  belongs_to :l1, class_name: :Language
  belongs_to :l2, class_name: :Language
  has_many :token_translations, dependent: :destroy
  has_one_attached :l1_audio, service: :s3_public
  has_timestamp [:timestamp]

  # Callbacks to automatically generate l1_audio when text_l1 or l1 language changes
  after_create :generate_l1_audio, if: :should_generate_audio?
  after_update :generate_l1_audio, if: :should_generate_audio_on_update?

  scope :ordered_by_timestamp, -> { order(timestamp: :asc) }

  # Class method to add calculated_end_timestamp to each phrase based on the next phrase in the medium
  def self.with_calculated_end_timestamps(phrase_collection, all_medium_phrases = nil)
    phrase_collection.each do |phrase|
      # Use provided medium phrases or fetch them
      medium_phrases = all_medium_phrases || phrase.medium.phrases.ordered_by_timestamp.to_a
      
      # Find the next phrase in the medium's phrase collection
      current_phrase_index = medium_phrases.find_index { |p| p.id == phrase.id }
      next_phrase = current_phrase_index ? medium_phrases[current_phrase_index + 1] : nil
      
      # Calculate end timestamp using next phrase or default to +5 seconds
      timestamp_end = next_phrase&.timestamp || to_string_timestamp(phrase.timestamp_seconds + 5)
      
      # Add the calculated end timestamp as a singleton method
      phrase.define_singleton_method(:calculated_end_timestamp) { timestamp_end }
    end
    
    phrase_collection
  end

  scope :between_durations, ->(from, to) {
  where(
    "(split_part(timestamp, ':', 1)::int * 60 + split_part(timestamp, ':', 2)::int) BETWEEN ? AND ?",
    from, to
  )
  }

  # Class method to convert seconds to timestamp string format ("MM:SS")
  def self.to_string_timestamp(timestamp_seconds)
    minutes = timestamp_seconds / 60
    seconds = timestamp_seconds % 60
    "#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
  end

  private

  # Check if we should generate audio on create
  def should_generate_audio?
    text_l1.present? && l1&.iso_name.present?
  end

  # Check if we should generate audio on update (only if text_l1 or l1 changed)
  def should_generate_audio_on_update?
    should_generate_audio? && (saved_change_to_text_l1? || saved_change_to_l1_id?)
  end

  # Generate and attach l1_audio using Azure Text-to-Speech in background job
  def generate_l1_audio
    return unless text_l1.present? && l1&.iso_name.present?

    begin
      Rails.logger.info "Queueing l1_audio generation for Phrase #{id}: '#{text_l1}' (#{l1.iso_name})"
      
      # Queue the audio generation job to run in background
      GeneratePhraseAudioJob.perform_later(id)
      
      Rails.logger.info "Successfully queued l1_audio generation job for Phrase #{id}"
      
    rescue => e
      Rails.logger.error "Error queueing l1_audio generation for Phrase #{id}: #{e.message}"
      # Don't raise the error to avoid breaking the save operation
      # Just log it and continue
    end
  end
end
