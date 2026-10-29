module Tools
  class AddVocabulary < AuthorizedTool
    required_scope "vocabulary:write"
    tool_name "add_vocabulary"
    description "Save a word or multiword phrase to your vocabulary. Requires vocabulary:write. " \
                "Always provide a natural example sentence in the source language demonstrating the vocabulary in use, " \
                "with additional words outside the selected vocabulary. Select inclusive zero-based whitespace word indexes. " \
                "For example: sentence 'Necesito darme prisa hoy.', indexes 1 through 2 saves 'darme prisa'. " \
                "Repeated saves return the existing item without changing its translation or practice state."
    input_schema(
      properties: {
        sentence: { type: "string", minLength: 1,
                    description: "A natural example sentence in the source language, containing the selected vocabulary and additional context words. A standalone word or phrase is rejected." },
        language: { type: "string", description: "Source language ISO code" },
        translation_language: { type: "string", description: "Translation language ISO code" },
        translation: { type: "string", minLength: 1 },
        start_word_index: { type: "integer", minimum: 0 },
        end_word_index: { type: "integer", minimum: 0 }
      },
      required: %w[sentence language translation_language translation start_word_index end_word_index]
    )

    def self.call(sentence:, language:, translation_language:, translation:, start_word_index:, end_word_index:, server_context:)
      auth_error = authorization_error(server_context)
      return auth_error if auth_error

      validate_example_sentence!(sentence, start_word_index, end_word_index)

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

    def self.validate_example_sentence!(sentence, start_index, end_index)
      words = sentence.split
      # Invalid selections are reported by the shared custom-vocabulary validator.
      return unless start_index >= 0 && end_index >= start_index && end_index < words.length

      context = words.first(start_index) + words.drop(end_index + 1)
      return if context.any? { |word| word.match?(/[\p{L}\p{N}]/u) }

      raise PhraseTokenUser::InvalidInput,
        "An example sentence is required. Retry with a natural sentence in the source language " \
        "demonstrating the selected word or phrase, include additional context words outside the selection, " \
        "and update start_word_index and end_word_index to select only the vocabulary."
    end
    private_class_method :validate_example_sentence!
  end
end
