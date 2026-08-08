require "test_helper"

# POST /users/auth/native_google with a Google ID token — the Android sign-in
# path (Credential Manager). The iOS path posts a serverAuthCode instead and
# trades it with Google, which is unchanged and not exercised here.
#
# The token is the *entire* proof of identity: nothing is fetched from Google
# afterwards, so every one of these checks is what stands between a stranger's
# JWT and a session on someone else's account.
class Users::NativeGoogleTest < ActionDispatch::IntegrationTest
  ISSUER = "https://accounts.google.com".freeze

  setup do
    @key = OpenSSL::PKey::RSA.generate(2048)
    @jwk = JSON::JWK.new(@key.public_key, kid: "test-key")
    @client_id = Rails.application.credentials.google_client_id
    @user = User.create!(
      email: "gonzo@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
  end

  test "signs in an existing user with a valid token" do
    post_token(claims(email: @user.email))

    assert_redirected_to root_path
    assert_signed_in
  end

  test "rejects a token minted for a different OAuth client" do
    # The attack this exists for: anyone can register their own Google client and
    # obtain validly-signed tokens from it. Only the audience distinguishes those
    # from tokens meant for us.
    post_token(claims(email: @user.email, aud: "999-someone-elses.apps.googleusercontent.com"))

    assert_rejected
  end

  test "rejects a token signed by the wrong key" do
    other_key = OpenSSL::PKey::RSA.generate(2048)
    post_token(claims(email: @user.email), signing_key: other_key)

    assert_rejected
  end

  test "rejects an expired token" do
    post_token(claims(email: @user.email, exp: 1.hour.ago.to_i))

    assert_rejected
  end

  test "rejects a token from an unexpected issuer" do
    post_token(claims(email: @user.email, iss: "https://accounts.evil.example"))

    assert_rejected
  end

  test "rejects a token whose email is unverified" do
    # Accounts are keyed on email, so an unverified address is a way to claim
    # somebody else's account by asserting their address at an identity provider.
    post_token(claims(email: @user.email, email_verified: false))

    assert_rejected
  end

  test "accepts the string form of email_verified" do
    post_token(claims(email: @user.email, email_verified: "true"))

    assert_redirected_to root_path
    assert_signed_in
  end

  test "accepts the bare issuer spelling Google also uses" do
    post_token(claims(email: @user.email, iss: "accounts.google.com"))

    assert_redirected_to root_path
    assert_signed_in
  end

  test "rejects a request carrying neither credential" do
    post "/users/auth/native_google", headers: native_headers

    assert_redirected_to new_user_session_path
    assert_equal "Missing Google credential", flash[:alert]
  end

  private

  def claims(email:, **overrides)
    {
      iss: ISSUER,
      aud: @client_id,
      sub: "google-uid-1",
      email: email,
      email_verified: true,
      name: "Gonzo",
      exp: 1.hour.from_now.to_i,
      iat: Time.now.to_i
    }.merge(overrides)
  end

  def post_token(claims, signing_key: @key)
    jwt = JSON::JWT.new(claims)
    jwt.kid = "test-key"
    token = jwt.sign(signing_key, :RS256).to_s

    # Stand in for the network fetch of Google's JWKS. The controller asks for the
    # key named by the token's `kid`; handing back ours is what makes a
    # self-signed token verifiable, and is the only thing stubbed.
    JSON::JWK::Set::Fetcher.stub(:fetch, @jwk) do
      post "/users/auth/native_google", params: { id_token: token }, headers: native_headers
    end
  end

  def native_headers
    { "User-Agent" => "LangletsNative/1.0 (Android);" }
  end

  def assert_signed_in
    follow_redirect!
    assert_not_equal new_user_session_path, path
  end

  def assert_rejected
    assert_redirected_to new_user_session_path
    assert_equal "Google authentication failed", flash[:alert]
  end
end
