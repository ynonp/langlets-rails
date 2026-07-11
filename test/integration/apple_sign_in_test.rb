require "test_helper"

class AppleSignInTest < ActionDispatch::IntegrationTest
  test "login page shows the Apple sign-in button" do
    get new_user_session_path

    assert_response :success
    assert_select "form[action=?]", user_apple_omniauth_authorize_path
  end

  test "signup page shows the Apple sign-in button" do
    get new_user_registration_path

    assert_response :success
    assert_select "form[action=?]", user_apple_omniauth_authorize_path
  end

  test "native_apple rejects a missing identity token" do
    post users_auth_native_apple_path

    assert_redirected_to new_user_session_path
    assert_equal "Missing identity token", flash[:alert]
  end

  test "native_apple rejects a forged identity token" do
    forged = JSON::JWT.new(
      iss: "https://appleid.apple.com",
      aud: "com.ynonp.langlets",
      sub: "001234.abcdef",
      email: "attacker@example.com",
      exp: 1.hour.from_now.to_i,
      iat: Time.now.to_i
    ).sign(OpenSSL::PKey::RSA.new(2048)).to_s

    post users_auth_native_apple_path, params: { identity_token: forged }

    assert_redirected_to new_user_session_path
    assert_equal "Apple authentication failed", flash[:alert]
    assert_nil User.find_by(email: "attacker@example.com")
  end

  test "from_omniauth creates a confirmed user for apple" do
    info = Users::OmniauthCallbacksController::AuthInfo.new(email: "apple-user@privaterelay.appleid.com", name: "Apple User")
    auth = Users::OmniauthCallbacksController::AuthHash.new(provider: "apple", uid: "001234.abcdef", info: info)

    user = User.from_omniauth(auth)

    assert user.persisted?
    assert_equal "apple", user.provider
    assert_equal "001234.abcdef", user.uid
    assert user.confirmed?
  end
end
