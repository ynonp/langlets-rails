require "test_helper"

class DailyChallengesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper
  NATIVE = { "User-Agent" => "LangletsNative" }.freeze

  setup do
    @user = User.create!(email: "challenge-page@example.test", password: "password123", confirmed_at: Time.zone.now)
    sign_in @user
  end

  def join_challenge(**extra)
    post daily_challenge_path, params: { language_ids: [languages(:french).id], notification_delivery: ["email"], reminder_time: "09:00", reminder_timezone: "UTC" }.merge(extra)
  end

  test "web starts with language selection and no enrollment on GET" do
    assert_no_difference "StarterChallenge.count" do
      get daily_challenge_path
    end
    assert_response :success
    assert_select '[data-testid="primary-web-header"]'
    assert_select 'input[name="language_ids[]"]', Language.count
    assert_select 'input[name="reminder_time"][type="time"]'
    assert_select 'select[name="reminder_timezone"]' 
    assert_select 'section[data-testid^="quest"]', 0
    assert_select 'a[href="/daily_challenge"][aria-current="page"]'
  end

  test "joining saves choices and renders only unlocked content for selected languages" do
    assert_enqueued_with(job: SendDailyChallengesJob) { join_challenge }
    assert_redirected_to daily_challenge_path
    follow_redirect!
    assert_response :success
    assert_select '[data-testid^="quest-"]', 0
    travel_to @user.reload.starter_challenge.daily_challenges.find_by!(day: 1).available_at + 1.second do
      get daily_challenge_path
      assert_select 'section[data-testid^="quest-"]', 1
      assert_select '#day-1 a[href*="url="]', minimum: 1
    end
    assert_select '#day-1 a[href*="x5PJoP9x-Ys"]', 0
    assert_select '#day-3 a[href*="url="]', 0
    assert_select '#day-1 form[action*="complete"]', 1
    assert_select '#day-2 form[action*="complete"]', 0
  end

  test "waiting message uses the chosen reminder timezone" do
    travel_to Time.utc(2026, 9, 25, 12) do
      join_challenge(reminder_time: "18:00", reminder_timezone: "Asia/Jerusalem")
      challenge = @user.reload.starter_challenge
      assert_equal Time.utc(2026, 9, 26, 15), challenge.pending_quest.available_at

      get daily_challenge_path
      assert_select '[data-testid="challenge-waiting"]', text: /18:00/
      assert_select '[data-testid="challenge-waiting"]', text: /15:00/, count: 0
    end
  end

  test "multiple languages appear when selected" do
    join_challenge(language_ids: [languages(:french).id, languages(:spanish).id])
    travel_to @user.reload.starter_challenge.daily_challenges.find_by!(day: 1).available_at + 1.second
    get daily_challenge_path
    assert_select '#day-1 h3', text: languages(:french).native_name
    assert_select '#day-1 h3', text: languages(:spanish).native_name
  end

  test "invalid selection renders an accessible error and does not enroll" do
    [[], ["not-a-language"], [languages(:french).id, -1]].each do |ids|
      assert_no_difference "StarterChallenge.count" do
        join_challenge(language_ids: ids)
      end
      assert_response :unprocessable_entity
      assert_select '[role="alert"]', text: I18n.t("daily_challenge.invalid_selection")
    end
  end

  test "invalid reminder time and timezone do not enroll" do
    [ { reminder_time: "25:00" }, { reminder_timezone: "Mars/Olympus" } ].each do |input|
      assert_no_difference "StarterChallenge.count" do
        join_challenge(**input)
      end
      assert_response :unprocessable_entity
    end
  end

  test "settings preserve empty delivery preferences and do not restart" do
    join_challenge
    original = @user.reload.starter_challenge.started_at
    join_challenge(language_ids: [languages(:spanish).id], notification_delivery: [""])
    assert_equal [], @user.reload.notification_delivery
    assert_equal original, @user.starter_challenge.started_at
    assert_equal 5, @user.starter_challenge.daily_challenges.count
  end

  test "completion is scoped to current account and locked quests reject writes" do
    join_challenge
    post complete_daily_challenge_path(day: 2)
    assert_response :unprocessable_entity
    travel_to @user.reload.starter_challenge.daily_challenges.find_by!(day: 1).available_at + 1.second
    post complete_daily_challenge_path(day: 1)
    assert_redirected_to daily_challenge_path
    assert @user.reload.starter_challenge.daily_challenges.find_by!(day: 1).completed_at?
    other = User.create!(email: "other-starter@example.test", password: "password123", confirmed_at: Time.zone.now)
    sign_in other
    post complete_daily_challenge_path(day: 1, starter_challenge_id: @user.starter_challenge.id)
    assert_response :not_found
  end

  test "all actions require authentication" do
    sign_out @user
    get daily_challenge_path
    assert_redirected_to new_user_session_path
    join_challenge
    assert_redirected_to new_user_session_path
    post complete_daily_challenge_path(day: 1)
    assert_redirected_to new_user_session_path
  end

  test "native renders app shell and asks push permission only after opting in" do
    join_challenge(notification_delivery: ["push"])
    get daily_challenge_path, headers: NATIVE
    assert_response :success
    assert_select 'body[data-native-tabs]'
    assert_select '[data-bridge--push-ask-value="true"]'
    @user.update!(notification_delivery: [])
    get daily_challenge_path, headers: NATIVE
    assert_select '[data-bridge--push-ask-value="false"]'
  end

  test "after five quests the page shows only daily practice" do
    join_challenge
    travel 7.days do
      get daily_challenge_path
      assert_response :success
      assert_select 'form[action*="complete"]', 0
      assert_select '[data-testid="daily-practice"]'
    end
  end

  test "Hebrew and Spanish interfaces render without missing translations" do
    join_challenge
    %w[he es].each do |locale|
      host! "#{locale}.langlets.app"
      sign_in @user
      get daily_challenge_path
      assert_response :success
      assert_no_match(/translation_missing|Translation missing/, response.body)
    end
  end
end
