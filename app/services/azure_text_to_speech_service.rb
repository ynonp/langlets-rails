# app/services/azure_text_to_speech_service.rb

# Legacy service wrapper for backward compatibility
# The main functionality has been moved to the AzureTextToSpeech concern
class AzureTextToSpeechService
  # Include the concern to access its functionality
  include AzureTextToSpeech

  # Maintain backward compatibility with existing API
  def self.synthesize(text:, lang: "en")
    synthesize_speech(text: text, lang: lang)
  end

  # Delegate class methods to the concern
  def self.get_voice(language_iso)
    super
  end

  def self.get_azure_language_code(language_iso)
    super
  end
end
