# app/services/azure_text_to_speech_service.rb

require 'net/http'
require 'uri'
require 'base64'
require 'wavefile' # Added for WAV conversion
require 'stringio'   # Added for in-memory buffer

class AzureTextToSpeechService
  # Supported output formats for Azure TTS raw audio.
  # We'll use 16kHz, 16-bit, mono PCM as it's a common standard for WAV.
  AZURE_PCM_OUTPUT_FORMAT = 'raw-16khz-16bit-mono-pcm'.freeze
  WAV_SAMPLE_RATE = 16000 # Must match the PCM format from Azure
  WAV_CHANNELS = 1        # Mono
  WAV_BITS_PER_SAMPLE = 16 # 16-bit

  def self.get_voice(language_iso)
    # Standardized voice selection based on language ISO code
    case language_iso.downcase # Normalize input
    when "en", "en-us", "en-gb" # Added common variations
      "en-US-AriaNeural"
    when "es", "es-es", "es-mx" # Added common variations
      "es-ES-ElviraNeural"
    when "fr", "fr-fr", "fr-ca" # Added common variations
      "fr-FR-DeniseNeural"
    when "ar", "ar-jo", "ar-eg", "ar-sa" # Added common variations
      "ar-JO-TaimNeural" # Using Jordanian as a default for Arabic
    when "he", "he-il"
      "he-IL-AvriNeural"
    when "ar-ps" # Palestinian Arabic
      "ar-JO-TaimNeural" # Azure might not have a specific ar-PS, fall back to a close one
    else
      "en-US-AriaNeural" # Default to English if language not found
    end
  end

  def self.get_azure_language_code(language_iso)
    # Maps language ISO codes to Azure's specific language codes for SSML
    case language_iso.downcase # Normalize input
    when "en", "en-us", "en-gb"
      "en-US"
    when "es", "es-es", "es-mx"
      "es-ES"
    when "ar", "ar-jo", "ar-eg", "ar-sa"
      "ar-JO"
    when "ar-ps"
      "ar-JO" # Fallback for Palestinian Arabic
    when "fr", "fr-fr", "fr-ca"
      "fr-FR"
    when "he", "he-il"
      "he-IL"
    else
      "en-US" # Default to US English
    end
  end

  def self.synthesize(text:, lang: "en")
    language_code = self.get_azure_language_code(lang)
    voice_name = self.get_voice(lang)
    key = Rails.application.credentials.dig(:azure, :tts, :key)
    region = Rails.application.credentials.dig(:azure, :tts, :region)

    # Robust check for credentials
    unless key && region
      Rails.logger.error "Azure TTS credentials missing. Please check config/credentials.yml.enc"
      raise "Azure TTS credentials missing"
    end

    # Step 1: Get access token
    token_uri = URI("https://#{region}.api.cognitive.microsoft.com/sts/v1.0/issueToken")
    token_request = Net::HTTP::Post.new(token_uri)
    token_request['Ocp-Apim-Subscription-Key'] = key
    token_request['Content-Length'] = '0' # Required for POST requests with no body

    begin
      token_response = Net::HTTP.start(token_uri.hostname, token_uri.port, use_ssl: token_uri.scheme == 'https', read_timeout: 10) do |http|
        http.request(token_request)
      end

      unless token_response.is_a?(Net::HTTPSuccess)
        Rails.logger.error "Azure TTS Token Error: #{token_response.code} - #{token_response.body}"
        raise "Azure TTS Token Error: #{token_response.code} - Failed to retrieve access token."
      end
      access_token = token_response.body
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => e
      Rails.logger.error "Azure TTS Token Network Error: #{e.message}"
      raise "Azure TTS Token Network Error: #{e.message}"
    end

    # Step 2: Build SSML request
    # Sanitize text input to prevent SSML injection if text comes from user input
    sanitized_text = CGI.escapeHTML(text)
    ssml = <<~SSML
      <speak version='1.0' xml:lang='#{language_code}'>
        <voice name='#{voice_name}'>#{sanitized_text}</voice>
      </speak>
    SSML

    tts_uri = URI("https://#{region}.tts.speech.microsoft.com/cognitiveservices/v1")
    tts_request = Net::HTTP::Post.new(tts_uri)
    tts_request['Authorization'] = "Bearer #{access_token}"
    tts_request['Content-Type'] = 'application/ssml+xml'
    # Request raw PCM audio data from Azure
    tts_request['X-Microsoft-OutputFormat'] = AZURE_PCM_OUTPUT_FORMAT
    tts_request['User-Agent'] = "RailsAzureTTS/#{Rails.version}" # More informative User-Agent
    tts_request.body = ssml

    begin
      tts_response = Net::HTTP.start(tts_uri.hostname, tts_uri.port, use_ssl: tts_uri.scheme == 'https', read_timeout: 20) do |http| # Increased timeout for TTS
        http.request(tts_request)
      end

      if tts_response.is_a?(Net::HTTPSuccess)
        raw_pcm_data = tts_response.body

        # Step 3: Convert raw PCM data to WAV format in memory
        wav_buffer_io = StringIO.new
        # Define the format for the wavefile gem, matching Azure's PCM output
        format = WaveFile::Format.new(WAV_CHANNELS, :pcm_16, WAV_SAMPLE_RATE)

        WaveFile::Writer.new(wav_buffer_io, format) do |writer|
          # The raw PCM data needs to be packed correctly if it's not already in the right sample format.
          # Azure's `raw-16khz-16bit-mono-pcm` should provide samples directly.
          # We need to convert the binary string of samples into an array of integers.
          # "s<*" unpacks a sequence of 16-bit signed little-endian integers.
          samples = raw_pcm_data.unpack("s<*")
          # Create a buffer of these samples for the writer
          wave_file_buffer_to_write = WaveFile::Buffer.new(samples, format)
          writer.write(wave_file_buffer_to_write)
        end

        # Step 4: Base64 encode the WAV data
        Base64.strict_encode64(wav_buffer_io.string)
      else
        Rails.logger.error "Azure TTS Synthesis Error: #{tts_response.code} - #{tts_response.body}"
        # Provide more context in the error message
        error_message = "Azure TTS Synthesis Error: #{tts_response.code}."
        error_message += " Response: #{tts_response.body}" if tts_response.body.present?
        raise error_message
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => e
      Rails.logger.error "Azure TTS Synthesis Network Error: #{e.message}"
      raise "Azure TTS Synthesis Network Error: #{e.message}"
    end
  end
end
