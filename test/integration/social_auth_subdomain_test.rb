require "test_helper"

class SocialAuthSubdomainTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    https!
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:google_oauth2)
  end

  test "Google login uses the canonical callback then returns to the Hebrew origin" do
    user = User.create!(
      email: "hebrew-google-login@example.com",
      password: "password123",
      confirmed_at: Time.zone.now,
      preferences: { "native_language" => "en" }
    )
    mock_google(email: user.email, uid: "hebrew-login")
    origin = "https://he.langlets.app/courses/song?from=login"

    host! "he.langlets.app"
    post user_google_oauth2_omniauth_authorize_path, params: { origin: origin }

    assert_redirected_to "https://langlets.app/users/auth/google_oauth2/callback"

    follow_redirect!

    assert_redirected_to origin
    assert_equal "he", user.reload.preferences["native_language"]
  end

  test "Google signup returns to the Hebrew origin and stores Hebrew for native apps" do
    email = "hebrew-google-signup@example.com"
    mock_google(email: email, uid: "hebrew-signup")
    origin = "https://he.langlets.app/"

    host! "he.langlets.app"
    post user_google_oauth2_omniauth_authorize_path, params: { origin: origin }
    follow_redirect!

    assert_redirected_to origin
    user = User.find_by!(email: email)
    assert_predicate user, :confirmed?
    assert_equal "he", user.preferences["native_language"]
  end

  test "social buttons preserve a safe return path on the original subdomain" do
    host! "he.langlets.app"

    get new_user_session_path(returnto: "/courses/song?from=login")

    assert_response :success
    assert_select "form[action=?]", user_google_oauth2_omniauth_authorize_path do
      assert_select "input[name=origin][value=?]",
        "https://he.langlets.app/courses/song?from=login"
    end
  end

  test "social buttons do not turn an external returnto into an OAuth origin" do
    host! "he.langlets.app"

    get new_user_registration_path(returnto: "https://attacker.example/path")

    assert_response :success
    assert_select "form[action=?]", user_google_oauth2_omniauth_authorize_path do
      assert_select "input[name=origin][value=?]", "https://he.langlets.app/"
    end
  end

  test "Spanish Google signup uses the canonical callback and returns to Spanish" do
    email = "spanish-google-signup@example.com"
    mock_google(email: email, uid: "spanish-signup")
    host! "es.langlets.app"
    post user_google_oauth2_omniauth_authorize_path, params: { origin: "https://es.langlets.app/" }
    assert_redirected_to "https://langlets.app/users/auth/google_oauth2/callback"
    follow_redirect!
    assert_redirected_to "https://es.langlets.app/"
    assert_equal "es", User.find_by!(email: email).native_language.iso_name
  end

  private

  def mock_google(email:, uid:)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email, name: "Hebrew Learner" }
    )
  end
end
