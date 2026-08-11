require "test_helper"

class EmailSignupTest < ActionDispatch::IntegrationTest
  test "email signup redirects to check-email instructions" do
    assert_difference "User.count", 1 do
      post user_registration_path, params: signup_params("web-signup@example.com")
    end

    assert_redirected_to user_registration_check_email_path
    follow_redirect!

    assert_response :success
    assert_select '[data-testid="check-email-page"]'
    assert_select "h1", I18n.t("devise.registrations.check_email.title")
    assert_select "a[href=?]", new_user_confirmation_path
  end

  {
    "iOS" => "LangletsNative (iOS)",
    "Android" => "LangletsNative (Android)"
  }.each do |platform, user_agent|
    test "#{platform} email signup shows check-email instructions as an auth root" do
      post user_registration_path,
        params: signup_params("#{platform.downcase}-signup@example.com"),
        headers: { "User-Agent" => user_agent }

      assert_redirected_to user_registration_check_email_path
      get user_registration_check_email_path, headers: { "User-Agent" => user_agent }

      assert_response :success
      assert_select '[data-testid="check-email-page"]'
      assert_select '[data-controller="bridge--tab-visibility"][data-bridge--tab-visibility-visible-value="false"]'
      assert_select '[data-testid="auth-close"]', count: 0
    end
  end

  test "invalid email signup stays on the signup form" do
    assert_no_difference "User.count" do
      post user_registration_path, params: signup_params("not-an-email")
    end

    assert_response :unprocessable_entity
    assert_select '[data-testid="check-email-page"]', count: 0
    assert_select "form[action=?]", user_registration_path
  end

  private

  def signup_params(email)
    {
      user: {
        email: email,
        password: "password123",
        password_confirmation: "password123"
      }
    }
  end
end
