require "test_helper"

class Api::V1::VocabularyControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "api-vocab@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    @english = languages(:english)
    @spanish = languages(:spanish)

    medium = Medium.create!(url: "https://www.youtube.com/watch?v=apiv1", language: @english)
    phrase = Phrase.create!(
      medium: medium, l1: @english, l2: @spanish,
      text_l1: "Hello world", text_l2: "Hola mundo", timestamp: "00:01:30"
    )
    @token_translation = TokenTranslation.create!(
      phrase: phrase, l1_start_index: 0, l1_end_index: 4,
      index_type: :character_index, translation: "Hola"
    )
    @user.saved_token_translations << @token_translation

    @token = create_access_token(@user)
  end

  test "requires a bearer token and advertises resource metadata" do
    get api_v1_vocabulary_url

    assert_response :unauthorized
    assert_includes @response.headers["WWW-Authenticate"], "resource_metadata="
    assert_includes @response.headers["WWW-Authenticate"], "/.well-known/oauth-protected-resource"
  end

  test "rejects tokens without the vocabulary:read scope" do
    wrong_scope = create_access_token(@user, scopes: "courses:read")

    get api_v1_vocabulary_url, headers: auth_headers(wrong_scope)

    assert_response :forbidden
  end

  test "rejects expired tokens" do
    expired = create_access_token(@user, expires_in: 2.hours)
    expired.update_column(:created_at, 3.hours.ago)

    get api_v1_vocabulary_url, headers: auth_headers(expired)

    assert_response :unauthorized
  end

  test "returns the user's vocabulary" do
    get api_v1_vocabulary_url, headers: auth_headers(@token)

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal 1, body["items"].size
    item = body["items"].first
    assert_equal "Hello", item["word"]
    assert_equal "Hola", item["translation"]
    assert_equal "Hello world", item["context"]
    assert_equal "Hola mundo", item["context_translation"]
    assert_equal "en", item["language"]
    assert_equal false, body["has_more"]
    assert_equal 1, body["page"]
  end

  test "filters by language and 422s on unknown language" do
    get api_v1_vocabulary_url, params: { language: "es" }, headers: auth_headers(@token)
    assert_response :success
    assert_empty JSON.parse(@response.body)["items"]

    get api_v1_vocabulary_url, params: { language: "zz" }, headers: auth_headers(@token)
    assert_response :unprocessable_entity
    assert_equal "unknown_language", JSON.parse(@response.body)["error"]
  end

  test "records token usage" do
    assert_nil @token.last_used_at

    get api_v1_vocabulary_url, headers: auth_headers(@token)

    assert_not_nil @token.reload.last_used_at
  end
end
