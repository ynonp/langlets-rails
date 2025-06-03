# app/services/azure_text_to_speech_service.rb

require 'net/http'
require 'uri'
require 'base64'

class AzureTextToSpeechService
  def self.get_voice(language_iso)
    case language_iso
    when "en"
      "en-US-AriaNeural"
    when "es"
      "es-ES-ElviraNeural"
    when "fr"
      "fr-FR-DeniseNeural"
    when "ar"
      "ar-JO-TaimNeural"
    when "he"
      "he-IL-AvriNeural"
    when "ar-PS"
      "ar-JO-TaimNeural"
    end
  end

  def self.get_azure_language_code(language_iso)
    case language_iso
    when "en"
      "en-US"
    when "es"
      "es-ES"
    when "ar" 
      "ar-JO"
    when "ar-PS" 
      "ar-JO"
    when "fr" 
      "fr-FR"
    when "he" 
      "he-IL"
    end
  end

  def self.synthesize(text:, lang: "en")
    language_code = self.get_azure_language_code(lang)
    voice_name = self.get_voice(lang)
    key = Rails.application.credentials.dig(:azure, :tts, :key)
    region = Rails.application.credentials.dig(:azure, :tts, :region)

    raise "Azure TTS credentials missing" unless key && region

    # Step 1: Get access token
    token_uri = URI("https://#{region}.api.cognitive.microsoft.com/sts/v1.0/issueToken")
    token_request = Net::HTTP::Post.new(token_uri)
    token_request['Ocp-Apim-Subscription-Key'] = key

    token_response = Net::HTTP.start(token_uri.hostname, token_uri.port, use_ssl: true) do |http|
      http.request(token_request)
    end

    access_token = token_response.body

    # Step 2: Build SSML request
    ssml = <<~SSML
      <speak version='1.0' xml:lang='#{language_code}'>
        <voice name='#{voice_name}'>#{text}</voice>
      </speak>
    SSML

    tts_uri = URI("https://#{region}.tts.speech.microsoft.com/cognitiveservices/v1")
    tts_request = Net::HTTP::Post.new(tts_uri)
    tts_request['Authorization'] = "Bearer #{access_token}"
    tts_request['Content-Type'] = 'application/ssml+xml'
    tts_request['X-Microsoft-OutputFormat'] = 'audio-16khz-32kbitrate-mono-mp3'
    tts_request['User-Agent'] = 'RailsAzureTTS'
    tts_request.body = ssml

    tts_response = Net::HTTP.start(tts_uri.hostname, tts_uri.port, use_ssl: true) do |http|
      http.request(tts_request)
    end

    if tts_response.code.to_i == 200
      Base64.strict_encode64(tts_response.body)
    else
      raise "Azure TTS Error: #{tts_response.code} - #{tts_response.body}"
    end
  end
end
