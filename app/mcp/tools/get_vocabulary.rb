module Tools
  class GetVocabulary < MCP::Tool
    tool_name "get_vocabulary"
    description "Get the authenticated user's saved vocabulary words with their translations " \
                "and the phrase each word was saved from. Paginated; newest first. " \
                "Optionally filter to one learning language by ISO code."
    input_schema(
      properties: {
        language: { type: "string", description: "ISO language code to filter by, e.g. 'es' or 'he'" },
        page: { type: "integer", minimum: 1, description: "Page number, starting at 1" },
        per_page: { type: "integer", minimum: 1, maximum: 100, description: "Items per page (default 25)" }
      },
      required: []
    )

    def self.call(language: nil, page: 1, per_page: PaginatedQuery::DEFAULT_PER_PAGE, server_context: nil)
      unless server_context[:scopes].include?("vocabulary:read")
        return MCP::Tool::Response.new(
          [ { type: "text", text: "This token is missing the vocabulary:read scope" } ], error: true
        )
      end

      result = VocabularyQuery.new(
        user: server_context[:user], language: language, page: page, per_page: per_page
      ).call
      MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(result) } ])
    rescue PaginatedQuery::UnknownLanguageError => e
      MCP::Tool::Response.new([ { type: "text", text: e.message } ], error: true)
    end
  end
end
