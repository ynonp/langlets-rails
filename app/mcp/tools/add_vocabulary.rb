module Tools
  class AddVocabulary < MCP::Tool
    tool_name "add_vocabulary"
    description "Save a word or multiword phrase to your vocabulary. Requires vocabulary:write. " \
                "Select inclusive zero-based whitespace word indexes in the sentence. " \
                "To save a standalone word or phrase, use it as the sentence and select all its words. " \
                "Repeated saves return the existing item without changing its translation or practice state."
    input_schema(
      properties: {
        sentence: { type: "string", minLength: 1 },
        language: { type: "string", description: "Source language ISO code" },
        translation_language: { type: "string", description: "Translation language ISO code" },
        translation: { type: "string", minLength: 1 },
        start_word_index: { type: "integer", minimum: 0 },
        end_word_index: { type: "integer", minimum: 0 }
      },
      required: %w[sentence language translation_language translation start_word_index end_word_index]
    )

    def self.call(sentence:, language:, translation_language:, translation:, start_word_index:, end_word_index:, server_context:)
      unless server_context[:scopes].include?("vocabulary:write")
        return MCP::Tool::Response.new([ { type: "text", text: "This token is missing the vocabulary:write scope; reconnect requesting this scope" } ], error: true)
      end

      source = Language.find_by(iso_name: language)
      target = Language.find_by(iso_name: translation_language)
      raise PhraseTokenUser::InvalidInput, "Unknown source or translation language ISO code" unless source && target

      saved = PhraseTokenUser.create_custom!(
        user: server_context[:user], sentence: sentence, language: source, translation_language: target,
        translation: translation, token_range: [ start_word_index, end_word_index ]
      )
      MCP::Tool::Response.new([ { type: "text", text: JSON.generate(id: saved.id, word: saved.word, translation: saved.translation) } ])
    rescue PhraseTokenUser::InputError, PhraseTokenUser::InvalidInput => e
      MCP::Tool::Response.new([ { type: "text", text: e.message } ], error: true)
    end
  end
end
