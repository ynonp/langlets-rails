module Tools
  # ChatGPT reads securitySchemes from both the descriptor and its _meta mirror.
  # Keep SDK-specific serialization here; every handler still enforces its scope.
  class AuthorizedTool < MCP::Tool
    class << self
      def required_scope(scope)
        @required_scope = scope
      end

      def to_h
        schemes = [ { type: "oauth2", scopes: [ @required_scope ] } ]
        super.merge(securitySchemes: schemes, _meta: (meta || {}).merge(securitySchemes: schemes))
      end

      def authorization_error(server_context)
        return if server_context[:scopes].include?(@required_scope)

        message = "This token is missing the #{@required_scope} scope; authorize access to continue"
        challenge = %(Bearer resource_metadata="#{server_context.fetch(:base_url)}/.well-known/oauth-protected-resource/mcp", ) +
          %(error="insufficient_scope", error_description="#{message}", scope="#{@required_scope}")
        MCP::Tool::Response.new(
          [ { type: "text", text: message } ], error: true,
          meta: { "mcp/www_authenticate" => [ challenge ] }
        )
      end
    end
  end
end
