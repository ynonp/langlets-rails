# OAuth discovery documents for AI agents. Doorkeeper 5.9 doesn't ship an
# RFC 8414 endpoint, so we serve both documents ourselves.
class WellKnownController < ActionController::API
  # RFC 8414: OAuth 2.0 Authorization Server Metadata
  def oauth_authorization_server
    base = request.base_url
    render json: {
      issuer: base,
      authorization_endpoint: "#{base}/oauth/authorize",
      token_endpoint: "#{base}/oauth/token",
      registration_endpoint: "#{base}/oauth/register",
      revocation_endpoint: "#{base}/oauth/revoke",
      scopes_supported: Doorkeeper.configuration.scopes.to_a,
      response_types_supported: [ "code" ],
      grant_types_supported: [ "authorization_code", "refresh_token" ],
      token_endpoint_auth_methods_supported: [ "none", "client_secret_basic", "client_secret_post" ],
      code_challenge_methods_supported: [ "S256" ]
    }
  end

  # RFC 9728: OAuth 2.0 Protected Resource Metadata (for MCP discovery)
  def oauth_protected_resource
    base = request.base_url
    render json: {
      resource: "#{base}/mcp",
      authorization_servers: [ base ],
      scopes_supported: Doorkeeper.configuration.scopes.to_a,
      bearer_methods_supported: [ "header" ]
    }
  end
end
