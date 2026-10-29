require "test_helper"

class Oauth::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  test "registers a public client" do
    post oauth_register_url, params: {
      client_name: "Claude",
      redirect_uris: [ "https://claude.ai/api/mcp/auth_callback" ],
      grant_types: [ "authorization_code", "refresh_token" ],
      response_types: [ "code" ],
      token_endpoint_auth_method: "none"
    }, as: :json

    assert_response :created
    body = JSON.parse(@response.body)
    assert body["client_id"].present?
    assert_nil body["client_secret"]
    assert_equal "none", body["token_endpoint_auth_method"]
    assert_equal [ "https://claude.ai/api/mcp/auth_callback" ], body["redirect_uris"]
    assert_equal "vocabulary:read courses:read vocabulary:write", body["scope"]

    application = Doorkeeper::Application.find_by(uid: body["client_id"])
    assert_equal false, application.confidential?
    assert application.dynamically_registered?
  end

  test "registers a confidential client with a secret" do
    post oauth_register_url, params: {
      client_name: "Server agent",
      redirect_uris: [ "https://agent.example.com/callback" ],
      token_endpoint_auth_method: "client_secret_basic"
    }, as: :json

    assert_response :created
    body = JSON.parse(@response.body)
    assert body["client_secret"].present?
    assert Doorkeeper::Application.find_by(uid: body["client_id"]).confidential?
  end

  test "allows loopback http redirect uris" do
    post oauth_register_url, params: {
      client_name: "langlets CLI",
      redirect_uris: [ "http://127.0.0.1:8917/callback" ],
      token_endpoint_auth_method: "none"
    }, as: :json

    assert_response :created
  end

  test "rejects missing redirect_uris" do
    post oauth_register_url, params: { client_name: "Bad" }, as: :json

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", JSON.parse(@response.body)["error"]
  end

  test "rejects non-loopback http redirect uris" do
    post oauth_register_url, params: {
      client_name: "Bad",
      redirect_uris: [ "http://evil.example.com/callback" ]
    }, as: :json

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", JSON.parse(@response.body)["error"]
  end

  test "narrows scopes to configured ones" do
    post oauth_register_url, params: {
      client_name: "Greedy",
      redirect_uris: [ "https://agent.example.com/callback" ],
      scope: "vocabulary:read vocabulary:write admin:everything",
      token_endpoint_auth_method: "none"
    }, as: :json

    assert_response :created
    assert_equal "vocabulary:read vocabulary:write", JSON.parse(@response.body)["scope"]
  end

  test "read-only registration supports later write consent without granting it by default" do
    post oauth_register_url, params: {
      client_name: "Read-first agent", redirect_uris: [ "https://agent.example.com/callback" ],
      scope: "vocabulary:read", token_endpoint_auth_method: "none"
    }, as: :json
    assert_response :created
    application = Doorkeeper::Application.find_by!(uid: JSON.parse(response.body)["client_id"])
    assert_includes application.scopes.to_a, "vocabulary:write"
    assert_not_includes Doorkeeper.configuration.default_scopes.to_a, "vocabulary:write"

    user = User.create!(email: "scope-upgrade@example.com", password: "password123", confirmed_at: Time.zone.now)
    sign_in user
    get oauth_authorization_path, params: {
      client_id: application.uid, redirect_uri: application.redirect_uri,
      response_type: "code", scope: "vocabulary:read vocabulary:write",
      code_challenge: "a" * 43, code_challenge_method: "S256"
    }
    assert_response :success
    assert_select "form input[name='scope'][value='vocabulary:read vocabulary:write']"
    assert_no_difference "Doorkeeper::AccessToken.count" do
      get oauth_authorization_path, params: {
        client_id: application.uid, redirect_uri: application.redirect_uri,
        response_type: "code", code_challenge: "a" * 43, code_challenge_method: "S256"
      }
      assert_response :success
      assert_select "form input[name='scope'][value='vocabulary:read']"
    end
    post oauth_authorization_path, params: {
      client_id: application.uid, redirect_uri: application.redirect_uri,
      response_type: "code", scope: "vocabulary:read vocabulary:write",
      code_challenge: "a" * 43, code_challenge_method: "S256"
    }
    assert_response :redirect
    assert_equal "vocabulary:read vocabulary:write", Doorkeeper::AccessGrant.order(:id).last.scopes.to_s
  end
end
