#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'base64'

# Check if API key is set
api_key = ENV['GEMINI_API_KEY']
if api_key.nil? || api_key.empty?
  puts "Please set GEMINI_API_KEY environment variable"
  exit 1
end

# Prepare the request
uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=#{api_key}")

http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'

# Usage: ruby script.rb "text" [language_code] [voice_name]
# Examples:
# ruby script.rb "si" "es" "Aoede"     # Spanish pronunciation
# ruby script.rb "si" "fr" "Aoede"     # French pronunciation  
# ruby script.rb "Hello world" "en"    # English
# ruby script.rb "Hola mundo" "es"     # Spanish
# ruby script.rb "Bonjour monde" "fr"  # French

text_to_speak = ARGV[0] || "Say cheerfully: Have a wonderful day!"
language_code = ARGV[1] || "en"  # Default to English
voice_name = ARGV[2] || "Aoede"  # Default voice

request_body = {
  "contents" => [{
    "parts" => [{
      "text" => text_to_speak
    }]
  }],
  "generationConfig" => {
    "responseModalities" => ["AUDIO"],
    "speechConfig" => {
      "voiceConfig" => {
        "prebuiltVoiceConfig" => {
          "voiceName" => voice_name
        }
      },
      "languageCode" => language_code
    }
  },
  "model" => "gemini-2.5-flash-preview-tts"
}

request.body = request_body.to_json

# Make the request
begin
  response = http.request(request)
  
  if response.code == '200'
    # Parse JSON response
    json_response = JSON.parse(response.body)
    
    # Extract base64 audio data
    base64_audio = json_response.dig('candidates', 0, 'content', 'parts', 0, 'inlineData', 'data')
    
    if base64_audio
      # Decode base64 and write to PCM file (binary mode)
      pcm_data = Base64.decode64(base64_audio)
      File.open('out.pcm', 'wb') do |file|
        file.write(pcm_data)
      end
      
      # Convert PCM to WAV using ffmpeg
      system('ffmpeg -f s16le -ar 24000 -ac 1 -i out.pcm out.wav')
      
      puts "Audio saved to out.wav"
    else
      puts "No audio data found in response"
      puts response.body
    end
  else
    puts "Error: #{response.code} - #{response.body}"
  end
rescue => e
  puts "Error: #{e.message}"
end
