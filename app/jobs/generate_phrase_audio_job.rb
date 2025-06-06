class GeneratePhraseAudioJob < ApplicationJob
  queue_as :default
  
  # Retry with exponential backoff if TTS service is temporarily unavailable
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # Discard job if phrase is deleted
  discard_on ActiveRecord::RecordNotFound

  def perform(phrase_id)
    phrase = Phrase.find(phrase_id)
    
    return unless phrase.text_l1.present? && phrase.l1&.iso_name.present?
    
    Rails.logger.info "Generating l1_audio for Phrase #{phrase_id}: '#{phrase.text_l1}' (#{phrase.l1.iso_name})"
    
    begin
      # Use the Azure TTS service to synthesize speech
      wav_io = Phrase.synthesize_speech(text: phrase.text_l1, lang: phrase.l1.iso_name)
      
      if wav_io
        # Generate filename with phrase ID and timestamp
        filename = "phrase_#{phrase_id}_l1_#{Time.current.to_i}.wav"
        
        # Attach the audio using Active Storage
        phrase.l1_audio.attach(
          io: wav_io,
          filename: filename,
          content_type: 'audio/wav'
        )
        
        Rails.logger.info "Successfully generated and attached l1_audio for Phrase #{phrase_id}"
      else
        Rails.logger.warn "Failed to generate audio for Phrase #{phrase_id}: TTS returned nil"
        raise "TTS service returned nil for phrase #{phrase_id}"
      end
      
    rescue => e
      Rails.logger.error "Error generating l1_audio for Phrase #{phrase_id}: #{e.message}"
      raise # Re-raise to trigger retry logic
    end
  end
end
