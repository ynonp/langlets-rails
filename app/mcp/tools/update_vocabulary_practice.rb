module Tools
  class UpdateVocabularyPractice < AuthorizedTool
    required_scope "vocabulary:write"
    tool_name "update_vocabulary_practice"
    description "Set a saved vocabulary item's last practice time (last_reviewed_at). Requires vocabulary:write. " \
                "Use the item id from get_vocabulary or add_vocabulary. Supply an ISO 8601 timestamp with timezone; " \
                "future dates are rejected. Reschedules next review using the item's current familiarity interval, " \
                "without changing familiarity or paused state."
    input_schema(
      properties: {
        id: { type: "integer", minimum: 1 },
        last_reviewed_at: { type: "string", description: "ISO 8601 timestamp with timezone, e.g. 2026-10-29T10:00:00Z" }
      },
      required: %w[id last_reviewed_at]
    )

    def self.call(id:, last_reviewed_at:, server_context:)
      auth_error = authorization_error(server_context)
      return auth_error if auth_error

      unless last_reviewed_at.match?(/T.*(?:Z|[+-]\d{2}:\d{2})\z/)
        raise ArgumentError, "last_reviewed_at must be an ISO 8601 timestamp with timezone"
      end
      practiced_at = Time.iso8601(last_reviewed_at)
      raise ArgumentError, "last_reviewed_at cannot be in the future" if practiced_at > Time.zone.now

      saved = nil
      server_context[:user].with_lock do
        saved = server_context[:user].phrase_token_users.find(id)
        level = PhraseTokenUser.familiarities.fetch(saved.familiarity)
        saved.update!(last_reviewed_at: practiced_at, last_review_lesson: nil,
          next_review_at: practiced_at + PhraseTokenUser::REVIEW_INTERVALS.fetch(level))
      end
      MCP::Tool::Response.new([ { type: "text", text: JSON.generate(
        id: saved.id, last_reviewed_at: saved.last_reviewed_at.iso8601, next_review_at: saved.next_review_at.iso8601
      ) } ])
    rescue ArgumentError => e
      MCP::Tool::Response.new([ { type: "text", text: e.message } ], error: true)
    rescue ActiveRecord::RecordNotFound
      MCP::Tool::Response.new([ { type: "text", text: "Vocabulary item not found" } ], error: true)
    end
  end
end
