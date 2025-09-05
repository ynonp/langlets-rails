class WhisperClient
  def self.transcribe_audio(filename, language_code:)
    api_key = Rails.application.credentials.dig(:openai_api_key)
    file_path =  Rails.root.join("audio", filename)
    HTTParty.post(
      "https://api.openai.com/v1/audio/transcriptions",
      headers: {
        "Authorization" => "Bearer #{api_key}"
      },
      body: {
        model: "gpt-4o-transcribe",
        file: File.new(file_path, "rb"),
        response_format: "json",
        language: language_code,
      }
    )
  end
end
