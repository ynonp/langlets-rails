require "test_helper"

class WellKnownControllerTest < ActionDispatch::IntegrationTest
  test "serves RFC 8414 authorization server metadata" do
    get "/.well-known/oauth-authorization-server"

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal "http://www.example.com", body["issuer"]
    assert_equal "http://www.example.com/oauth/authorize", body["authorization_endpoint"]
    assert_equal "http://www.example.com/oauth/token", body["token_endpoint"]
    assert_equal "http://www.example.com/oauth/register", body["registration_endpoint"]
    assert_equal "http://www.example.com/oauth/revoke", body["revocation_endpoint"]
    assert_equal [ "S256" ], body["code_challenge_methods_supported"]
    assert_equal [ "code" ], body["response_types_supported"]
    assert_includes body["scopes_supported"], "vocabulary:read"
    assert_includes body["token_endpoint_auth_methods_supported"], "none"
  end

  test "serves RFC 9728 protected resource metadata at both paths" do
    [ "/.well-known/oauth-protected-resource", "/.well-known/oauth-protected-resource/mcp" ].each do |path|
      get path

      assert_response :success
      body = JSON.parse(@response.body)
      assert_equal "http://www.example.com/mcp", body["resource"]
      assert_equal [ "http://www.example.com" ], body["authorization_servers"]
      assert_includes body["scopes_supported"], "courses:read"
    end
  end
end
