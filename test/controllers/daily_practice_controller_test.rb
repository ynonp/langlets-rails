require "test_helper"

class DailyPracticeControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "legacy-practice@example.test", password: "password123", confirmed_at: Time.zone.now)
    sign_in @user
  end

  test "historical practice links redirect to the unified daily challenge" do
    get daily_practice_path(language_code: "ar-JO")
    assert_redirected_to daily_challenge_path
  end

  test "requires authentication" do
    sign_out @user
    get daily_practice_path
    assert_redirected_to new_user_session_path
  end
end
