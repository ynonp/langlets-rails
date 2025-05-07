require 'json'

module Ai
  module Gemini
    API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-04-17:generateContent"

    def self.extract_phrases_from_audio(file_path, audio_language_name, translation_language_name, from_mmss, to_mmss)
      prompt = <<END
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

      headers = { 'Content-Type' => 'application/json' }
      url = "#{API_URL}?key=#{Rails.application.credentials.dig(:google_api_key)}"
      body = {
        contents: [
          {
            parts: [
              { inline_data: {
                  mime_type: 'audio/mp3',
                  data: Base64.strict_encode64(File.read(Rails.root.join(file_path)))
                } },
              { text: prompt }
            ]
          }
        ]
      }.to_json
      response = HTTParty.post(url, headers: headers, body: body)

      pp response
      parse_llm_json_response(response.parsed_response)

    end

    def self.extract_keywords_from_phrases(l1_text, l2_text, l1_name, l2_name)
      system_prompt = <<END
      You are an expert linguist speaking both #{l1_name} and #{l2_name}.

      Given the input of parallel phrases below in the two languages, 
      your mission is to create a language alignment mapping between the phrases in the two languages.
      A mapping maps one or more words from one language to another, for example "mesa" maps to "table" but "soy" maps to "I am"
      Indices should be based on character positions, starting from 0.
      l1_alternatives and l1_questions should relate to the phrase in `l1_text` between `l1_start_index` and `l1_end_index`.

      Here is the information we need about each mapping:
      1. l1_index - character index in l1 where the matched text begins
      2. l2_index - character index in l2 where the matched text begins
      3. l1_text - text from the first phrase
      4. l2_text - its matching translation from the second phrase
      5. l1_questions - question or questions in language l1 that are answered by the specified word

      ## Explanation of `l1_questions`
      Only generate natural, context-based comprehension questions. These questions should:
      Ask about actions, events, subjects, or objects in the sentence.
      Be answerable directly from the sentence.
      Use interrogatives like Who, What, When, Where, or Why in a natural language format.
      Mimic the kinds of questions a teacher would ask to check a student’s understanding of the sentence's meaning, not its grammar.
      Use short and concise questions - 3-6 words

      Examples:
      * What happened?
      * Who ate the cake?
      * What did she do?
      * When was the cake eaten?

      Avoid These BAD Question Types
      Do not generate questions that:
      * Ask for definitions, translations, or parts of speech.
      * Focus on grammatical labels (e.g., “What is the article?” or “What is the conjunction?”).
      * Refer to linguistic terminology (e.g., “What verb means...”).

      Examples for bad questions that should NOT be used:
      * What verb means "to indicate"?
      * What is the translation of "Magnet"?
      * What is the grammatical conjunction?
      * What is the article for the word "magnet"?

      Remember - it's better not to write a question than write an inaccurate one.

      ## Output Format

      Output format instructions:
      1. Respond with the JSON only no prefix or suffix.
      2. Response JSON should match the following schema:

      ```
        {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "type": "array",
          "items": {
            "title": "WordMapping",
            "type": "object",
            "properties": {
              "l1_index": { "type": "number" },
              "l2_index": { "type": "number" },
              "l1_text": { "type": "string" },
              "l2_text": { "type": "string" },
              "l1_questions": { "type": "array", "items": {
                "type": "string"
              }}
            },
            "required": ["l1_index", "l2_index", "l1_text", "l2_text"],
            "additionalProperties": false
          }
        }
      ```
END

      example1_user = <<END
      {
        "l1": "Hoy te voy a enseñar algo nuevo.",
        "l2": "Today I'm going to teach you something new."
      }
END

      example1_assistant = <<END
      [{"l1_text":"Hoy","l1_index":0,"l2_index":0,"l2_text":"Today","l1_questions":["Cuando te voy a enseñar algo nuevo?"]},{"l1_text":"te","l1_index":4,"l2_index":26,"l2_text":"you","l1_questions":[]},{"l1_text":"voy a","l1_index":7,"l2_index":6,"l2_text":"I'm going to","l1_questions":[]},{"l1_text":"enseñar","l_index":13,"l2_index":16,"l2_text":"to teach","l1_questions":["¿Qué vas a hacer hoy?"]},{"l1_text":"algo","l1_index":21,"l2_index":29,"l2_text":"something"},{"l1_text":"nuevo","l1_index":26,"l2_index":39,"l2_text":"new"}]
END
      
      prompt = <<END

      ```json
      {
        "l1": "#{l1_text}",
        "l2": "#{l2_text}"
      }
      ```      
END
      client = OpenAI::Client.new
      response = client.chat(
        parameters: {
          model: "o4-mini", # Required.
          messages: [
            { role: "system", content: system_prompt},
            { role: "user", content: example1_user },
            { role: "assistant", content: example1_assistant },
            { role: "user", content: prompt}
          ],
        }
      )
      chat_response = response.dig("choices", 0, "message", "content").gsub(/\A```(?:json)?\s*|\s*```\z/, '')
      pp chat_response
      JSON.parse(chat_response)
    end

    def self.extract_phrases_from_video(video_url, video_language_name, translation_language_name, from_mmss, to_mmss)
      prompt = <<END
      You are an expert #{video_language_name} teacher teaching #{translation_language_name} speaking students.

      Extract from the video the key sentences required to understand the text.
      Remember the video could be in multiple languages - we only want phrases in #{video_language_name}. Do not include text in other languages.
      Print 50 #{video_language_name} sentences from the video and their translation to #{translation_language_name} in JSON format.
      Use only sentences with 4-10 words, so they are easy for students to learn.

      1. Respond with the JSON only no prefix or suffix.
      2. Response JSON should match the following schema:

      ```
        {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "#{video_language_name}": {
                "type": "string"
              },
              "#{translation_language_name}": {
                "type": "string"
              },
              "timestamp": {
                "type": "string"
              }
            },
            "required": ["#{video_language_name}", "#{translation_language_name}", "timestamp"],
            "additionalProperties": false
          }
        }
      ```
END
      headers = { 'Content-Type' => 'application/json' }
      url = "#{API_URL}?key=#{Rails.application.credentials.dig(:google_api_key)}"
      body = {
        contents: [
          {
            parts: [
              { file_data: { file_uri: video_url } },
              { text: prompt }
            ]
          }
        ]
      }.to_json
      response = HTTParty.post(url, headers: headers, body: body)
      parse_llm_json_response(response.parsed_response)
    end

    private

    def self.parse_llm_json_response(response_body)
      content = response_body.dig("candidates", 0, "content", "parts", 0, "text")

      # Remove triple backticks and optional 'json'
      content = content.gsub(/\A```(?:json)?\s*|\s*```\z/, '')

      # Then parse it as JSON
      JSON.parse(content)
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse LLM JSON response: #{e.message}")
      []
    end
  end
end
