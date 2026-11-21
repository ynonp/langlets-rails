module Dictionary
  # The OpenAI media calls behind a Dictionary card: a flat illustration of the
  # headword's meaning, and a spoken headword. Both return raw bytes; the jobs
  # own attaching them. Plain HTTP rather than RubyLLM because RubyLLM has no
  # speech endpoint and its image helper would add a second code path for the
  # same two-line request.
  module Media
    IMAGE_MODEL = "gpt-image-1-mini".freeze
    SPEECH_MODEL = "gpt-4o-mini-tts".freeze
    SPEECH_VOICE = "coral".freeze
    API = "https://api.openai.com/v1".freeze

    class Error < StandardError; end

    STYLE = "Minimal flat vector illustration on a dark navy background (#1A2635), " \
            "thin rounded line art in off-white and a single bright green (#4ADE80) accent, " \
            "no text, no letters, no numbers, generous empty space. Scene: ".freeze

    module_function

    def illustrate(scene)
      response = post("/images/generations", {
        model: IMAGE_MODEL,
        prompt: STYLE + scene.to_s,
        size: "1536x1024",
        quality: "low",
        output_format: "webp",
        output_compression: 80,
        n: 1
      }, timeout: 120)
      encoded = response.parsed_response.dig("data", 0, "b64_json")
      raise Error, "image response had no data" if encoded.blank?

      Base64.decode64(encoded)
    end

    def speak(text, language:)
      response = post("/audio/speech", {
        model: SPEECH_MODEL,
        voice: SPEECH_VOICE,
        input: text.to_s,
        instructions: "Pronounce this #{language.english_name} word clearly and naturally, at a slightly slow learner pace.",
        response_format: "mp3"
      }, timeout: 60)
      raise Error, "speech response was empty" if response.body.blank?

      response.body
    end

    def post(path, body, timeout:)
      response = HTTParty.post(API + path,
        headers: { "Authorization" => "Bearer #{api_key}", "Content-Type" => "application/json" },
        body: body.to_json, timeout: timeout)
      raise Error, "OpenAI #{path} failed (#{response.code}): #{response.body.to_s.first(300)}" unless response.success?

      response
    end

    def api_key
      Rails.application.credentials.openai_api_key.presence || raise(Error, "openai_api_key is not configured")
    end
  end
end
