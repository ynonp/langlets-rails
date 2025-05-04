require "openai"

client = OpenAI::Client.new()
audio_language_name = "Spanish"
translation_language_name = "English"

system_prompt = <<END
      You are an expert #{audio_language_name} teacher teaching #{translation_language_name} speaking students.

      Extract from the audio the key sentences required to understand the text.
      Remember the audio could be in multiple languages - we only want phrases in #{audio_language_name}. Do not include text in other languages.
      create 50 #{audio_language_name} sentences. 
      Select the most important 50 phrases from the audio and print them out with relevant timestamps format mm:ss.

      Use only sentences with 4-10 words, so they are easy for students to learn.
      Break down long or compound sentences into shorter factual statements.
      Ensure each extracted sentence clearly expresses one idea or fact.
      Maintain as much as possible from the original meaning and vocabulary, while simplifying the text to learnable sentence form.

      1. Respond with the JSON only no prefix or suffix.
      2. Response JSON should match the following schema:

      ```
        {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "#{audio_language_name}": {
                "type": "string"
              },
              "#{translation_language_name}": {
                "type": "string"
              },
              "timestamp": {
                "type": "string"
              }
            },
            "required": ["#{audio_language_name}", "#{translation_language_name}", "timestamp"],
            "additionalProperties": false
          }
        }
      ```
END

file_id = client.files.upload(
  parameters: {
    file: "audio/kJQP7kiw5Fk.mp3",
    purpose: "assistants"
  }
)["id"]

response = client.chat(
  parameters: {
    model: "o4-mini", # Required.
    messages: [
      { role: "system", content: system_prompt},
      { role: "user", content: [{type: "input_audio", file: file_id }]}
    ],
  }
)
pp response