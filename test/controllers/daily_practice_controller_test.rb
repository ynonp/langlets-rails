require "test_helper"

class DailyPracticeControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "daily-practice-route@example.test", password: "password123", confirmed_at: Time.zone.now)
    @challenge = StarterChallenge.enroll!(user: @user, language_ids: [languages(:arabic).id], delivery: [])
    sign_in @user
  end

  test "practice link is unavailable before the starter quests end" do
    get daily_practice_path(language_code: "ar-JO")
    assert_response :not_found
  end

  test "after day five, empty library gets a useful start prompt" do
    travel_to @challenge.local_time_on(@challenge.first_challenge_on + 5) do
      get daily_practice_path(language_code: "ar-JO")
      assert_redirected_to daily_challenge_path
      follow_redirect!
      assert_includes response.body, "Import a video or save some words"
    end
  end

  test "saved words open the user's review lesson" do
    medium = Medium.create!(url: "https://www.youtube.com/watch?v=practicetest", language: languages(:arabic))
    phrase = create_translated_phrase!(medium: medium, l1: languages(:arabic), l2: languages(:english),
      text_l1: "مرحبا بالعالم", text_l2: "Hello world", timestamp: "00:00:01")
    token = create_translated_token!(phrase: phrase, l1_start_index: 0, l1_end_index: 4,
      index_type: :character_index, translation: "Hello")
    @user.saved_phrase_tokens << token
    travel_to @challenge.local_time_on(@challenge.first_challenge_on + 5) do
      get daily_practice_path(language_code: "ar-JO")
      assert_redirected_to review_lessons_path(language_code: "ar-JO")
    end
  end

  test "requires authentication" do
    sign_out @user
    get daily_practice_path(language_code: "ar-JO")
    assert_redirected_to new_user_session_path
  end
end
