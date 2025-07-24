class Phrase < ApplicationRecord
  include AzureTextToSpeech
  
  belongs_to :medium
  belongs_to :l1, class_name: :Language
  belongs_to :l2, class_name: :Language
  belongs_to :text_l1_multi, class_name: 'MultiScriptText', foreign_key: 'text_l1_id', optional: true
  belongs_to :text_l2_multi, class_name: 'MultiScriptText', foreign_key: 'text_l2_id', optional: true
  has_many :token_translations, dependent: :destroy
  has_one_attached :l1_audio, service: :s3_public
  has_timestamp [:timestamp]

  # Store temporary text values during object creation
  attr_accessor :temp_text_l1, :temp_text_l2

  # Callback to create multi-script texts before validation
  before_validation :create_multi_script_texts_from_temp_values

  # Callbacks to automatically generate l1_audio when text_l1 or l1 language changes
  after_create :generate_l1_audio, if: :should_generate_audio?
  after_update :generate_l1_audio, if: :should_generate_audio_on_update?

  scope :ordered_by_timestamp, -> { order(timestamp: :asc) }

  # Backward compatibility methods - get text content from multi-script texts
  def text_l1
    text_l1_multi&.default_content
  end

  def text_l2
    text_l2_multi&.default_content
  end

  # Helper methods for setting text content (creates multi-script texts if needed)
  def text_l1=(value)
    if persisted? && l1.present?
      # Update existing record
      set_l1_text_directly(value)
    else
      # Store for later processing during validation
      @temp_text_l1 = value
    end
  end

  def text_l2=(value)
    if persisted? && l2.present?
      # Update existing record
      set_l2_text_directly(value)
    else
      # Store for later processing during validation
      @temp_text_l2 = value
    end
  end

  # New methods for multi-script functionality
  def text_l1_for_script(script)
    text_l1_multi&.content_for_script(script)
  end

  def text_l2_for_script(script)
    text_l2_multi&.content_for_script(script)
  end

  # Check if phrase has script variants
  def has_script_variants?
    (text_l1_multi&.script_variants&.count || 0) > 1 || 
    (text_l2_multi&.script_variants&.count || 0) > 1
  end

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

  # Callback to create multi-script texts from temporary values
  def create_multi_script_texts_from_temp_values
    if @temp_text_l1.present? && l1.present? && text_l1_multi.blank?
      set_l1_text_directly(@temp_text_l1)
    end
    
    if @temp_text_l2.present? && l2.present? && text_l2_multi.blank?
      set_l2_text_directly(@temp_text_l2)
    end
  end

  def set_l1_text_directly(value)
    return unless value.present? && l1.present?
    
    script = l1.default_script || Script.find_by(code: 'Latn')
    return unless script
    
    if text_l1_multi.present?
      variant = text_l1_multi.variant_for_script(script)
      if variant
        variant.update!(content: value)
      else
        text_l1_multi.script_variants.create!(script: script, content: value)
      end
    else
      multi_text = MultiScriptText.create!(language: l1)
      multi_text.script_variants.create!(script: script, content: value)
      self.text_l1_multi = multi_text
    end
  end

  def set_l2_text_directly(value)
    return unless value.present? && l2.present?
    
    script = l2.default_script || Script.find_by(code: 'Latn')
    return unless script
    
    if text_l2_multi.present?
      variant = text_l2_multi.variant_for_script(script)
      if variant
        variant.update!(content: value)
      else
        text_l2_multi.script_variants.create!(script: script, content: value)
      end
    else
      multi_text = MultiScriptText.create!(language: l2)
      multi_text.script_variants.create!(script: script, content: value)
      self.text_l2_multi = multi_text
    end
  end

  # Check if we should generate audio on create
  def should_generate_audio?
    text_l1.present? && l1&.iso_name.present?
  end

  # Check if we should generate audio on update (only if text_l1 or l1 changed)
  def should_generate_audio_on_update?
    should_generate_audio? && (saved_change_to_l1_id? || text_l1_multi_changed?)
  end

  # Helper to detect if multi-script text changed
  def text_l1_multi_changed?
    saved_change_to_text_l1_id? || 
    (text_l1_multi&.script_variants&.any? { |v| v.saved_change_to_content? })
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
