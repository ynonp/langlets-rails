require "test_helper"

class App::NativeTokensControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "native-token@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    new_user_session_path
  end

  test "requires an authenticated native session" do
    post app_native_token_url, headers: native_headers

    assert_redirected_to %r{/users/sign_in}
  end

  test "issues a narrow token for the signed-in native app" do
    sign_in @user

    post app_native_token_url(lang: "es"), headers: native_headers

    assert_response :success
    body = response.parsed_body
    token = Doorkeeper::AccessToken.by_token(body.fetch("access_token"))
    assert_equal @user.id, token.resource_owner_id
    assert_equal App::NativeTokensController::CLIENT_UID, token.application.uid
    assert_equal "imports:read imports:write credits:read", token.scopes.to_s
    assert_operator Time.zone.parse(body.fetch("expires_at")), :>, 29.days.from_now
  end

  test "reuses a recent unexpired token" do
    sign_in @user

    post app_native_token_url(lang: "es"), headers: native_headers
    first = response.parsed_body.fetch("access_token")
    post app_native_token_url(lang: "es"), headers: native_headers

    assert_equal first, response.parsed_body.fetch("access_token")
    assert_equal 1, @user.oauth_access_tokens.count
  end

  test "native sign out revokes the share token" do
    sign_in @user
    post app_native_token_url(lang: "es"), headers: native_headers
    token = Doorkeeper::AccessToken.by_token(response.parsed_body.fetch("access_token"))

    delete destroy_user_session_url(returnto: "/app"), headers: native_headers

    assert token.reload.revoked?
  end

  private

  def native_headers
    { "User-Agent" => "LangletsNative/1.4" }
  end
end
