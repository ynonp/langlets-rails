require "test_helper"

class Oauth::RegistrationsControllerTest < ActionDispatch::IntegrationTest
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
    assert_equal "vocabulary:read courses:read", body["scope"]

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
      scope: "vocabulary:read admin:everything",
      token_endpoint_auth_method: "none"
    }, as: :json

    assert_response :created
    assert_equal "vocabulary:read", JSON.parse(@response.body)["scope"]
  end
end
