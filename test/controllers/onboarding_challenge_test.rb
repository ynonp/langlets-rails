require "test_helper"

class OnboardingChallengeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  NATIVE = { "User-Agent" => "LangletsNative" }.freeze

  test "native welcome links to target language selection before video selection" do
    get onboarding_welcome_path, headers: NATIVE
    assert_select 'a[href="/onboarding/language"]'
    get onboarding_language_path, headers: NATIVE
    assert_response :success
    assert_select 'input[name="language_ids[]"]', Language.count
    assert_select '[data-bridge--tab-visibility-visible-value="false"]'
  end

  test "guest choices survive authentication and enroll once" do
    post onboarding_language_path, headers: NATIVE,
      params: { language_ids: [languages(:french).id, languages(:spanish).id], notification_delivery: ["email", "push"], reminder_time: "18:30", reminder_timezone: "Europe/Berlin" }
    assert_redirected_to onboarding_video_path
    user = User.create!(email: "onboarding-starter@example.test", password: "password123", confirmed_at: Time.zone.now)
    sign_in user
    assert_difference "StarterChallenge.count", 1 do
      get daily_challenge_path, headers: NATIVE
    end
    assert_response :success
    assert_equal 2, user.reload.starter_challenge.languages.count
    assert_equal %w[email push], user.notification_delivery
    assert_equal "18:30", user.starter_challenge.reminder_time
    assert_equal "Europe/Berlin", user.starter_challenge.reminder_timezone
    assert_equal user.starter_challenge.started_at.in_time_zone("Europe/Berlin").to_date + 1,
      user.starter_challenge.first_challenge_on
    assert_no_difference "StarterChallenge.count" do
      get daily_challenge_path, headers: NATIVE
    end
  end

  test "invalid guest choice stays on selection and does not start challenge" do
    post onboarding_language_path, headers: NATIVE, params: { language_ids: ["invalid"] }
    assert_response :unprocessable_entity
    assert_select '[role="alert"]'
  end

  test "web uses the challenge tab instead of native onboarding" do
    get onboarding_language_path
    assert_redirected_to root_path
    post onboarding_language_path, params: { language_ids: [languages(:french).id] }
    assert_redirected_to root_path
  end

  test "authenticated legacy onboarding links lead to challenge settings" do
    user = User.create!(email: "legacy-starter@example.test", password: "password123", confirmed_at: Time.zone.now)
    sign_in user
    get onboarding_language_path, headers: NATIVE
    assert_redirected_to daily_challenge_path
    post onboarding_language_path, headers: NATIVE, params: { language_ids: [] }
    assert_redirected_to daily_challenge_path
  end
end
