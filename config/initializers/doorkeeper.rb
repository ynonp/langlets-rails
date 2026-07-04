# frozen_string_literal: true

# OAuth 2.1 provider for AI agents (MCP clients, the langlets CLI).
# Clients self-register via POST /oauth/register (RFC 7591) and discover the
# server via /.well-known/oauth-authorization-server (RFC 8414).
Doorkeeper.configure do
  orm :active_record

  # Inherit the app controller so the consent screen renders with the app
  # layout, theme helper and stylesheets.
  base_controller "ApplicationController"

  resource_owner_authenticator do
    current_user || redirect_to(new_user_session_path(returnto: request.fullpath))
  end

  # /oauth/applications management UI is for the site admin only.
  admin_authenticator do
    unless current_user&.admin?
      redirect_to(new_user_session_path(returnto: request.fullpath))
    end
  end

  # OAuth 2.1: authorization code + PKCE only. No implicit, no password grant.
  grant_flows %w[authorization_code]
  use_refresh_token

  # PKCE is mandatory for public clients (DCR'd agent clients and the CLI are
  # public; confidential clients authenticate with their secret instead).
  force_pkce
  pkce_code_challenge_methods %w[S256]

  access_token_expires_in 2.hours
  revoke_previous_authorization_code_token

  # Agents that request no scope get read access to vocabulary and courses.
  default_scopes :"vocabulary:read", :"courses:read"
  enforce_configured_scopes

  # Loopback redirect URIs stay http so native/CLI clients can receive the
  # callback locally (RFC 8252); everything else must be https.
  force_ssl_in_redirect_uri { |uri| !%w[localhost 127.0.0.1 ::1].include?(uri.host) }
end
