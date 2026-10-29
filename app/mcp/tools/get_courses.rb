module Tools
  class GetCourses < AuthorizedTool
    required_scope "courses:read"
    tool_name "get_courses"
    description "List published langlets courses in a given language. " \
                "Paginated; newest first. Each course links to its page on the site."

    LANGUAGE_CODES = Language.pluck(:iso_name).sort

    input_schema(
      properties: {
        language: { type: "string", enum: LANGUAGE_CODES, description: "ISO language code of the courses, e.g. 'es' or 'he'" },
        page: { type: "integer", minimum: 1, description: "Page number, starting at 1" },
        per_page: { type: "integer", minimum: 1, maximum: 100, description: "Items per page (default 25)" }
      },
      required: [ "language" ]
    )

    def self.call(language:, page: 1, per_page: PaginatedQuery::DEFAULT_PER_PAGE, server_context: nil)
      auth_error = authorization_error(server_context)
      return auth_error if auth_error

      result = CoursesQuery.new(
        language: language, user: server_context[:user],
        page: page, per_page: per_page, base_url: server_context[:base_url]
      ).call
      MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(result) } ])
    rescue PaginatedQuery::UnknownLanguageError => e
      MCP::Tool::Response.new([ { type: "text", text: e.message } ], error: true)
    end
  end
end
