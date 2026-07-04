# Helpers for tests that exercise the agent-facing OAuth surface (REST API,
# MCP endpoint, token management page).
module OauthTestHelpers
  def create_oauth_app(name: "Test Agent", confidential: false, redirect_uri: "https://agent.example.com/callback")
    Doorkeeper::Application.create!(
      name: name,
      redirect_uri: redirect_uri,
      scopes: "vocabulary:read courses:read",
      confidential: confidential
    )
  end

  def create_access_token(user, application: nil, scopes: "vocabulary:read courses:read", expires_in: 2.hours)
    Doorkeeper::AccessToken.create!(
      application: application || create_oauth_app,
      resource_owner_id: user.id,
      scopes: scopes,
      expires_in: expires_in.to_i
    )
  end

  def auth_headers(token)
    { "Authorization" => "Bearer #{token.plaintext_token}" }
  end
end

ActiveSupport::TestCase.include(OauthTestHelpers)
