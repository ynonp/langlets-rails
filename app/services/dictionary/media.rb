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

    # One subject, centered and small enough to leave margins: the card crops
    # the image to a wide strip and overlays a label top-left and a button
    # top-right, and anything extra in the picture competes with the word.
    STYLE = "Minimal flat vector icon-style illustration on a plain dark navy background (#1A2635), " \
            "thin rounded line art in off-white with a single bright green (#4ADE80) accent. " \
            "Draw only the subject described — nothing else: no furniture, surfaces, props, people or scenery unless the description names them. " \
            "Center it, keep it within the middle half of the image with wide empty margins on every side. " \
            "No text, letters or numbers. Subject: ".freeze

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

    # `accent` is the learner's own Dictionary instructions for the language
    # (e.g. "Palestinian colloquial Arabic"), so a dialect they asked for in
    # the card is also the one they hear.
    def speak(text, language:, accent: nil)
      instructions = "Pronounce this #{language.english_name} word clearly and naturally, at a slightly slow learner pace."
      instructions += " The learner's notes on the variety to use: #{accent}" if accent.present?
      response = post("/audio/speech", {
        model: SPEECH_MODEL,
        voice: SPEECH_VOICE,
        input: text.to_s,
        instructions: instructions,
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
