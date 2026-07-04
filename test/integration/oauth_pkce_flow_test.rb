require "test_helper"

# End-to-end OAuth 2.1 flow as an agent client would drive it:
# authorize (with S256 PKCE) -> consent -> code exchange -> API call.
class OauthPkceFlowTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "pkce@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    @application = Doorkeeper::Application.create!(
      name: "PKCE Agent",
      redirect_uri: "https://agent.example.com/callback",
      scopes: "vocabulary:read courses:read",
      confidential: false
    )

    @verifier = SecureRandom.urlsafe_base64(48)
    @challenge = Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(@verifier), padding: false)
  end

  def sign_in(user)
    post user_session_url, params: { user: { email: user.email, password: "password123" } }
  end

  def authorize_params(overrides = {})
    {
      client_id: @application.uid,
      redirect_uri: @application.redirect_uri,
      response_type: "code",
      scope: "vocabulary:read courses:read",
      state: "test-state",
      code_challenge: @challenge,
      code_challenge_method: "S256"
    }.merge(overrides)
  end

  def obtain_authorization_code
    sign_in(@user)
    post oauth_authorization_url, params: authorize_params

    assert_response :redirect
    redirect = URI.parse(@response.headers["Location"])
    assert_equal "agent.example.com", redirect.host
    query = URI.decode_www_form(redirect.query).to_h
    assert_equal "test-state", query["state"]
    query["code"]
  end

  test "unauthenticated authorize redirects to login preserving the return path" do
    get oauth_authorization_url, params: authorize_params

    assert_redirected_to %r{/users/sign_in}
  end

  test "authenticated authorize renders the consent screen" do
    sign_in(@user)
    get oauth_authorization_url, params: authorize_params

    assert_response :success
    assert_includes @response.body, "PKCE Agent"
  end

  test "public client cannot authorize without PKCE" do
    sign_in(@user)
    get oauth_authorization_url, params: authorize_params(code_challenge: nil, code_challenge_method: nil)

    assert_not_includes [ 200 ], @response.status
  end

  test "full code exchange with correct verifier grants a working token" do
    code = obtain_authorization_code

    post oauth_token_url, params: {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: @application.redirect_uri,
      client_id: @application.uid,
      code_verifier: @verifier
    }

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["access_token"].present?
    assert body["refresh_token"].present?
    assert_equal "vocabulary:read courses:read", body["scope"]

    # Token works against the API (fresh session, bearer only)
    reset!
    get api_v1_vocabulary_url, headers: { "Authorization" => "Bearer #{body["access_token"]}" }
    assert_response :success
  end

  test "code exchange fails with a wrong or missing verifier" do
    code = obtain_authorization_code

    post oauth_token_url, params: {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: @application.redirect_uri,
      client_id: @application.uid,
      code_verifier: "wrong-verifier-wrong-verifier-wrong-verifier"
    }
    assert_response :bad_request

    post oauth_token_url, params: {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: @application.redirect_uri,
      client_id: @application.uid
    }
    assert_response :bad_request
  end

  test "refresh token grant issues a new access token" do
    code = obtain_authorization_code

    post oauth_token_url, params: {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: @application.redirect_uri,
      client_id: @application.uid,
      code_verifier: @verifier
    }
    refresh_token = JSON.parse(@response.body)["refresh_token"]

    post oauth_token_url, params: {
      grant_type: "refresh_token",
      refresh_token: refresh_token,
      client_id: @application.uid
    }

    assert_response :success
    assert JSON.parse(@response.body)["access_token"].present?
  end

  test "revoked tokens stop working" do
    token = create_access_token(@user, application: @application)

    get api_v1_vocabulary_url, headers: auth_headers(token)
    assert_response :success

    token.revoke

    get api_v1_vocabulary_url, headers: auth_headers(token)
    assert_response :unauthorized
  end
end
