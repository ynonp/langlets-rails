require "test_helper"

class BetaOnboardingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  NATIVE = { "User-Agent" => "LangletsNative" }.freeze

  test "beta explanation is a mobile onboarding step before choosing languages" do
    User.stub(:beta_pro?, true) do
      get onboarding_welcome_path, headers: NATIVE
      assert_select 'a[href=?]', onboarding_beta_path
      get onboarding_beta_path, headers: NATIVE
      assert_response :success
      assert_select 'h1', text: "You're Pro during beta"
      assert_includes response.body, "unlimited imports"
      assert_select 'a[href=?]', onboarding_language_path
      assert_select '[data-bridge--tab-visibility-visible-value="false"]'
    end
  end

  test "closed beta skips its step and web browsers use web entry" do
    get onboarding_beta_path, headers: NATIVE
    assert_redirected_to onboarding_language_path
    User.stub(:beta_pro?, true) do
      get onboarding_beta_path
      assert_redirected_to root_path
    end
  end

  test "beta Pro status renders without a subscription instead of redirecting in a loop" do
    user = User.create!(email: "beta-status@example.test", password: "password123", confirmed_at: Time.zone.now)
    sign_in user
    User.stub(:beta_pro?, true) do
      get app_pro_path, headers: NATIVE
      assert_redirected_to app_pro_success_path
      get app_pro_success_path, headers: NATIVE
      assert_response :success
      assert_includes response.body, "unlimited imports"
      assert_nil user.pro_subscription
    end
  end
end
