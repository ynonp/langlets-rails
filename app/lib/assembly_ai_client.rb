class AssemblyAiClient
  attr_reader :base_url, :headers

  def initialize
    @base_url = 'https://api.assemblyai.com'
    @headers = {
      'authorization' => Rails.application.credentials.dig(:assembly_ai_key),
      'content-type' => 'application/json'
    }
  end
  
  def upload_audio(filename)
    file_path = Rails.root.join("audio", filename)

    response = HTTParty.post(
      "#{base_url}/v2/upload",
      headers: headers,
      body: File.binread(file_path)
    )

    raise "HTTP Error #{response.code}: #{response.message} - #{response.body}" unless response.code == 200
    response.parsed_response["upload_url"]
  end

  def transcribe_audio(filename, language_code:)
    audio_url = upload_audio(filename)
    data = {
      audio_url: audio_url,
      speech_model: "best",
      language_code:,
    }
    url = "#{base_url}/v2/transcript"
    response = HTTParty.post(url, headers: headers, body: data.to_json)
    raise "HTTP Error #{response.code}: #{response.message} - #{response.body}" unless response.code == 200
    transcript_id = response.parsed_response["id"]
    poll_until_completion(transcript_id)
  end

  def poll_until_completion(transcript_id)
    polling_endpoint = "#{base_url}/v2/transcript/#{transcript_id}"
    loop do
      poll_response = HTTParty.get(polling_endpoint, headers: headers)
      raise "HTTP Error #{poll_response.code}: #{poll_response.message} - #{poll_response.body}" unless poll_response.code == 200

      transcription_result = poll_response.parsed_response

      case transcription_result["status"]
      when "completed"
        return transcription_result
      when "error"
        raise "Transcription failed: #{transcription_result['error']}"
      else
        sleep 3
      end
    end
  end
end
