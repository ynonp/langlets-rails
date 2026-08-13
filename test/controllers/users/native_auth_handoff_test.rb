require "test_helper"

# The Android browser-to-web-view session handoff, end to end.
#
# On Android a GitHub or Apple sign-in has to run in a Chrome Custom Tab, whose
# cookies belong to Chrome rather than to the app, so the session it establishes
# is in the wrong jar. These endpoints carry it across. What they carry is a live
# session for someone's account over a `langlets://` deep link that any installed
# app may also receive — so most of what follows is about the ways that must not
# be spendable by whoever intercepts it.
class Users::NativeAuthHandoffTest < ActionDispatch::IntegrationTest
  VERIFIER = "a-verifier-only-the-app-that-started-the-flow-knows".freeze

  setup do
    @user = User.create!(
      email: "kermit@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @challenge = NativeAuthHandoff.challenge_for(VERIFIER)
  end

  # --- starting a flow ----------------------------------------------------

  test "starts a provider flow and marks the browser as native" do
    get "/users/auth/native_handoff_start", params: { provider: "github", challenge: @challenge }

    assert_redirected_to "/users/auth/github?native_app=1"
  end

  test "refuses a provider it does not offer" do
    # The value lands in a redirect target on an unauthenticated endpoint, which
    # is the shape of an open redirect if it is ever taken on trust.
    get "/users/auth/native_handoff_start",
      params: { provider: "https://evil.example.com/steal", challenge: @challenge }

    assert_redirected_to new_user_session_path
  end

  test "refuses a challenge that is not a base64url digest" do
    get "/users/auth/native_handoff_start", params: { provider: "github", challenge: "short" }

    assert_redirected_to new_user_session_path
  end

  # --- minting a token ----------------------------------------------------

  test "native_success hands back a token when a challenge was registered" do
    sign_in_through_browser_flow

    get "/users/auth/native_success"

    assert_equal @user, NativeAuthHandoff.redeem(handoff_token_from_redirect, VERIFIER)
  end

  test "native_success mints nothing for a flow that never registered a challenge" do
    # This is the iOS shape: ASWebAuthenticationSession shares a cookie jar with
    # the web view, so there is nothing to hand over and no token should exist.
    sign_in_as(@user)

    get "/users/auth/native_success", headers: native_headers

    assert_redirected_to "langlets://auth-success"
    assert_equal 0, NativeAuthHandoff.count
  end

  test "native_success reports failure when the flow did not authenticate anyone" do
    get "/users/auth/native_handoff_start", params: { provider: "github", challenge: @challenge }

    get "/users/auth/native_success"

    assert_redirected_to "langlets://auth-failure"
    assert_equal 0, NativeAuthHandoff.count
  end

  test "native_success carries only the handoff token" do
    sign_in_through_browser_flow

    get "/users/auth/native_success"

    assert_nil redirect_query["ios_lang"]
    assert_not_nil redirect_query["handoff"]
  end

  # --- spending a token ---------------------------------------------------

  test "redeeming establishes the session in the caller's cookie jar" do
    token = issue_token

    get "/users/auth/native_handoff", params: { token: token, verifier: VERIFIER }

    assert_response :success
    assert_signed_in
  end

  test "a token cannot be spent twice" do
    token = issue_token

    get "/users/auth/native_handoff", params: { token: token, verifier: VERIFIER }
    reset!
    get "/users/auth/native_handoff", params: { token: token, verifier: VERIFIER }

    assert_response :unauthorized
    assert_not_signed_in
  end

  test "a token is useless without the verifier" do
    # The attack this exists for: another app registers `langlets://` and
    # receives the deep link. It gets the token and nothing else, because the
    # verifier never left the device that started the flow.
    token = issue_token

    get "/users/auth/native_handoff", params: { token: token, verifier: "guessed" }

    assert_response :unauthorized
    assert_not_signed_in
  end

  test "a failed redemption burns the token rather than allowing another try" do
    token = issue_token

    get "/users/auth/native_handoff", params: { token: token, verifier: "guessed" }
    reset!
    get "/users/auth/native_handoff", params: { token: token, verifier: VERIFIER }

    assert_response :unauthorized
    assert_not_signed_in
  end

  test "an expired token is refused" do
    token = issue_token
    travel NativeAuthHandoff::TTL + 1.second

    get "/users/auth/native_handoff", params: { token: token, verifier: VERIFIER }

    assert_response :unauthorized
    assert_not_signed_in
  end

  test "an unknown token is refused" do
    get "/users/auth/native_handoff",
      params: { token: SecureRandom.urlsafe_base64(32), verifier: VERIFIER }

    assert_response :unauthorized
    assert_not_signed_in
  end

  test "minting a token clears tokens whose flows were abandoned" do
    stale = NativeAuthHandoff.issue!(@user, @challenge)
    travel NativeAuthHandoff::TTL + 1.second

    NativeAuthHandoff.issue!(@user, @challenge)

    assert_nil NativeAuthHandoff.redeem(stale, VERIFIER)
    assert_equal 1, NativeAuthHandoff.count
  end

  private

  # Everything the Custom Tab does before the app hears about it: register the
  # challenge, then authenticate. The session cookie the sign-in leaves behind is
  # Chrome's — the whole reason the rest of this exists — but within one
  # integration session it stands in for that browser.
  def sign_in_through_browser_flow
    get "/users/auth/native_handoff_start", params: { provider: "github", challenge: @challenge }
    sign_in_as(@user)
  end

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  def issue_token
    NativeAuthHandoff.issue!(@user, @challenge).tap { reset! }
  end

  def redirect_query
    Rack::Utils.parse_query(URI.parse(response.headers["Location"]).query)
  end

  def handoff_token_from_redirect
    redirect_query.fetch("handoff")
  end

  def native_headers
    { "User-Agent" => "LangletsNative/1.0 (Android);" }
  end

  def assert_signed_in
    get root_path
    assert_response :success
    assert_not_equal new_user_session_path, path
  end

  def assert_not_signed_in
    get "/profile"
    assert_redirected_to new_user_session_path
  end
end
