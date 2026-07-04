# Streamable-HTTP MCP endpoint for AI agents. Stateless JSON mode: every POST
# is self-contained, no sessions or SSE streams (rack-timeout friendly).
class McpController < ActionController::API
  before_action :authenticate!

  def handle
    server = MCP::Server.new(
      name: "langlets",
      version: "1.0.0",
      tools: [ Tools::GetVocabulary, Tools::GetCourses ],
      server_context: { user: @current_user, scopes: @token_scopes, base_url: request.base_url }
    )
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      server, stateless: true, enable_json_response: true
    )

    status, transport_headers, body = transport.handle_request(request)
    transport_headers.each { |key, value| response.set_header(key, value) }
    render body: body.join, status: status, content_type: transport_headers["Content-Type"] || "application/json"
  end

  private

  def authenticate!
    bearer = request.authorization.to_s[/\ABearer (.+)\z/, 1]
    token = Doorkeeper::AccessToken.by_token(bearer) if bearer
    if token&.accessible?
      @current_user = User.find_by(id: token.resource_owner_id)
      @token_scopes = token.scopes.to_a
      if @current_user
        touch_token_last_used(token)
        return
      end
    end

    # RFC 9728 pointer lets MCP clients discover the OAuth server and
    # self-onboard (metadata -> dynamic registration -> PKCE flow).
    response.set_header(
      "WWW-Authenticate",
      %(Bearer realm="langlets", resource_metadata="#{request.base_url}/.well-known/oauth-protected-resource/mcp")
    )
    render status: :unauthorized, json: { error: "unauthorized" }
  end

  def touch_token_last_used(token)
    return if token.last_used_at.present? && token.last_used_at > 1.minute.ago

    token.update_column(:last_used_at, Time.current)
  end
end
