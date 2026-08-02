require "test_helper"

class TokenTranslationUsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "saved-token-state@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=saved-token-state",
      language: languages(:english)
    )
    phrase = Phrase.create!(
      medium:,
      l1: languages(:english),
      text_l1: "Saved",
      timestamp: "00:01.00"
    )
    @token = phrase.phrase_tokens.create!(l1_start_index: 0, l1_end_index: 0)
    @user.phrase_token_users.create!(phrase_token: @token, language: languages(:english))

    post user_session_url, params: {
      user: { email: @user.email, password: "password123" }
    }
  end

  test "index returns authoritative saved token ids without caching" do
    get token_translation_users_url, as: :json

    assert_response :success
    assert_equal [@token.id], response.parsed_body["token_ids"]
    assert_includes response.headers["Cache-Control"], "private"
    assert_includes response.headers["Cache-Control"], "no-store"
  end
end
