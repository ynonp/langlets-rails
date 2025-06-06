class GenerateTokenAudioJob < ApplicationJob
  queue_as :default
  
  # Retry with exponential backoff if TTS service is temporarily unavailable
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # Discard job if token_translation is deleted
  discard_on ActiveRecord::RecordNotFound

  def perform(token_translation_id)
    token_translation = TokenTranslation.find(token_translation_id)
    
    # Check if we have the necessary data for audio generation
    return unless token_translation.original_text.present? && token_translation.phrase&.l1&.iso_name.present?
    
    Rails.logger.info "Generating l1_audio for TokenTranslation #{token_translation_id}: '#{token_translation.original_text}' (#{token_translation.phrase.l1.iso_name})"
    
    begin
      # Use the Azure TTS service to synthesize speech for the token's text
      wav_io = TokenTranslation.synthesize_speech(
        text: token_translation.original_text, 
        lang: token_translation.phrase.l1.iso_name
      )
      
      if wav_io
        # Generate filename with token_translation ID and timestamp
        filename = "token_translation_#{token_translation_id}_l1_#{Time.current.to_i}.wav"
        
        # Attach the audio using Active Storage
        token_translation.l1_audio.attach(
          io: wav_io,
          filename: filename,
          content_type: 'audio/wav'
        )
        
        Rails.logger.info "Successfully generated and attached l1_audio for TokenTranslation #{token_translation_id}"
      else
        Rails.logger.warn "Failed to generate audio for TokenTranslation #{token_translation_id}: TTS returned nil"
        raise "TTS service returned nil for token_translation #{token_translation_id}"
      end
      
    rescue => e
      Rails.logger.error "Error generating l1_audio for TokenTranslation #{token_translation_id}: #{e.message}"
      raise # Re-raise to trigger retry logic
    end
  end
end
