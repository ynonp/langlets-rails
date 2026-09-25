require "test_helper"

class Api::V1::NativeTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(email: "native-api@example.test", password: "password123", confirmed_at: Time.zone.now)
    @token = create_access_token(@user, scopes: "native")
    @course = Course.create!(name: "Native course", slug: "native-course", main_media_url: "https://www.youtube.com/watch?v=abcdefghijk", user: @user, language: languages(:spanish), status: :published)
    publish_privately(@course)
    @lesson = @course.lessons.create!(name: "One", slug: "one", user: @user, order: 1)
    @activity = @lesson.activities.create!(type: "Activities::ReadTranslatedActivity", user: @user, order: 1)
  end

  test "native endpoints require their explicit scope and ignore cookies" do
    get "/api/v1/native/bootstrap"
    assert_response :unauthorized
    get "/api/v1/native/bootstrap", headers: auth_headers(create_access_token(@user))
    assert_response :forbidden
    get "/api/v1/native/bootstrap", headers: auth_headers(@token)
    assert_response :ok
    assert_equal @user.id, response.parsed_body.dig("user", "id")
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "credentials issue refreshable native session and unconfirmed accounts fail" do
    post "/api/v1/native/session", params: { email: @user.email, password: "password123" }, as: :json
    assert_response :ok
    assert_equal @user.id, response.parsed_body["user_id"]
    assert response.parsed_body["refresh_token"].present?
    @user.update!(confirmed_at: nil)
    post "/api/v1/native/session", params: { email: @user.email, password: "password123" }, as: :json
    assert_response :unauthorized
  end

  test "course and lesson bundles enforce readability" do
    get "/api/v1/native/courses/#{@course.slug}/download", headers: auth_headers(@token)
    assert_response :ok
    assert_equal @activity.id, response.parsed_body.dig("lessons", 0, "activities", 0, "id")
    assert response.parsed_body.dig("lessons", 0, "offline_until")
    stranger = User.create!(email: "stranger-native@example.test", password: "password123", confirmed_at: Time.zone.now)
    get "/api/v1/native/lessons/#{@lesson.id}", headers: auth_headers(create_access_token(stranger, scopes: "native"))
    assert_response :not_found
  end

  test "operation replay and second operation cannot award completion twice" do
    operation = { operation_id: SecureRandom.uuid, payload: { kind: "lesson_complete", lesson_id: @lesson.id } }
    assert_difference -> { @user.activity_logs.count }, 1 do
      2.times do
        post "/api/v1/native/mutations", params: operation, headers: auth_headers(@token), as: :json
        assert_response :ok
      end
      post "/api/v1/native/mutations", params: operation.merge(operation_id: SecureRandom.uuid), headers: auth_headers(@token), as: :json
      assert_response :ok
    end
    assert_equal 1, @user.lesson_users.count
    operation[:payload] = { kind: "activity_complete", activity_id: @activity.id }
    post "/api/v1/native/mutations", params: operation, headers: auth_headers(@token), as: :json
    assert_response :conflict
    assert_equal 0, @user.activity_users.count
  end

  test "mutations reject foreign progress and roll back receipt" do
    stranger = User.create!(email: "outsider-native@example.test", password: "password123", confirmed_at: Time.zone.now)
    assert_no_difference "NativeMutationReceipt.count" do
      post "/api/v1/native/mutations", params: { operation_id: SecureRandom.uuid, payload: { kind: "lesson_complete", lesson_id: @lesson.id } }, headers: auth_headers(create_access_token(stranger, scopes: "native")), as: :json
      assert_response :not_found
    end
  end

  test "custom vocabulary is serialized with Unicode token boundaries" do
    Current.set(translation_language: languages(:english)) do
      entry = PhraseTokenUser.create_custom!(user: @user, sentence: "hola mundo", language: languages(:spanish), token_range: 1..1, translation: "world")
      get "/api/v1/native/vocabulary", headers: auth_headers(@token)
      assert_response :ok
      assert_equal entry.id, response.parsed_body.dig("items", 0, "id")
      assert_equal "mundo", response.parsed_body.dig("items", 0, "token", "text")
    end
  end

  test "logout revokes native credential" do
    delete "/api/v1/native/session", headers: auth_headers(@token)
    assert_response :no_content
    get "/api/v1/native/bootstrap", headers: auth_headers(@token)
    assert_response :unauthorized
  end
  test "native response shapes satisfy the published contract" do
    require "json-schema"
    document = JSON.parse(File.read(Rails.root.join("docs/native-ios/openapi.json")))
    schemas = JSON.parse(JSON.generate(document.fetch("components").fetch("schemas")).gsub("#/components/schemas/", "#/definitions/"))
    {
      "/api/v1/native/bootstrap" => "Bootstrap",
      "/api/v1/native/courses" => "CoursePage",
      "/api/v1/native/courses/#{@course.slug}/download" => "Download",
      "/api/v1/native/challenge" => "Challenge",
      "/api/v1/native/playlists" => "PlaylistPage",
      "/api/v1/native/notifications" => "NotificationPage"
    }.each do |path, schema|
      get path, headers: auth_headers(@token)
      assert_response :ok
      JSON::Validator.validate!({ "$schema" => "http://json-schema.org/draft-04/schema#", "definitions" => schemas,
        "$ref" => "#/definitions/#{schema}" }, response.parsed_body)
    end
  end

  test "extension credentials cannot read or mutate the native account" do
    post "/api/v1/native/extension_token", headers: auth_headers(@token)
    assert_response :ok
    headers = { "Authorization" => "Bearer #{response.parsed_body.fetch('access_token')}" }
    get "/api/v1/native/bootstrap", headers: headers
    assert_response :forbidden
    post "/api/v1/native/mutations", params: { operation_id: SecureRandom.uuid, payload: { kind: "lesson_complete", lesson_id: @lesson.id } }, headers: headers, as: :json
    assert_response :forbidden
  end

  test "invalid mutation leaves no receipt and does not trust client XP" do
    assert_no_difference "NativeMutationReceipt.count" do
      post "/api/v1/native/mutations", params: { operation_id: SecureRandom.uuid, payload: { kind: "word_create", sentence: "hello", language: "es", token_start: 50, token_end: 50, translation: "hola" } }, headers: auth_headers(@token), as: :json
      assert_response :unprocessable_entity
    end
    post "/api/v1/native/mutations", params: { operation_id: SecureRandom.uuid, payload: { kind: "activity_complete", activity_id: @activity.id, xp: 999999 } }, headers: auth_headers(@token), as: :json
    assert_response :ok
    assert_equal @activity.xp_value, @user.activity_logs.sum(:xp_gained)
  end

  test "saved vocabulary survives loss of course access but unsaved private tokens cannot be saved" do
    medium = Medium.create!(url: @course.main_media_url, language: languages(:spanish))
    @lesson.update!(medium: medium)
    phrase = medium.phrases.create!(l1: languages(:spanish), text_l1: "hola mundo", timestamp: "00:01")
    token = phrase.phrase_tokens.create!(l1_start_index: 0, l1_end_index: 0, index_type: :word_index)
    token.token_translations.create!(language: languages(:english), translation: "hello")
    post "/api/v1/native/mutations", params: { operation_id: SecureRandom.uuid, payload: { kind: "word_save", token_id: token.id } }, headers: auth_headers(@token), as: :json
    assert_response :ok
    @user.provision_default_channel!.unpublish!(@course)
    get "/api/v1/native/vocabulary", headers: auth_headers(@token)
    assert_response :ok
    assert_equal token.id, response.parsed_body.dig("items", 0, "token_id")
    other = phrase.phrase_tokens.create!(l1_start_index: 1, l1_end_index: 1, index_type: :word_index)
    post "/api/v1/native/mutations", params: { operation_id: SecureRandom.uuid, payload: { kind: "word_save", token_id: other.id } }, headers: auth_headers(@token), as: :json
    assert_response :not_found
  end

  test "playlist membership is account scoped and inaccessible courses stay hidden" do
    post "/api/v1/native/playlists", params: { name: "My practice" }, headers: auth_headers(@token), as: :json
    assert_response :created
    id = response.parsed_body.fetch("id")
    patch "/api/v1/native/playlists/#{id}", params: { course_slug: @course.slug, included: true }, headers: auth_headers(@token), as: :json
    assert_response :ok
    get "/api/v1/native/playlists/#{id}", headers: auth_headers(@token)
    assert_equal @course.id, response.parsed_body.dig("courses", "items", 0, "id")
    @user.provision_default_channel!.unpublish!(@course)
    get "/api/v1/native/playlists/#{id}", headers: auth_headers(@token)
    assert_equal [], response.parsed_body.dig("courses", "items")
  end

  test "account native language controls content and is validated" do
    patch "/api/v1/native/account", params: { native_language: "invalid" }, headers: auth_headers(@token), as: :json
    assert_response :unprocessable_entity
    patch "/api/v1/native/account", params: { native_language: "he", notification_delivery: [] }, headers: auth_headers(@token), as: :json
    assert_response :ok
    assert_equal "he", @user.reload.native_language.iso_name
    assert_equal [], @user.notification_delivery
  end

  test "native session can refresh using the normal OAuth endpoint" do
    credentials = Native::Session.issue(@user)
    post "/oauth/token", params: { grant_type: "refresh_token", refresh_token: credentials[:refresh_token], client_id: credentials[:client_id] }, as: :json
    assert_response :ok
    headers = { "Authorization" => "Bearer #{response.parsed_body.fetch('access_token')}" }
    get "/api/v1/native/bootstrap", headers: headers
    assert_response :ok
  end

  test "offline completions preserve a bounded practice date" do
    practiced = 2.days.ago.change(usec: 0)
    post "/api/v1/native/mutations", params: { operation_id: SecureRandom.uuid, payload: { kind: "lesson_complete", lesson_id: @lesson.id, occurred_at: practiced.iso8601 } }, headers: auth_headers(@token), as: :json
    assert_response :ok
    assert_equal practiced, @user.activity_logs.last.created_at
    assert_equal practiced, @user.lesson_users.last.created_at
    post "/api/v1/native/mutations", params: { operation_id: SecureRandom.uuid, payload: { kind: "activity_complete", activity_id: @activity.id, occurred_at: 1.year.from_now.iso8601 } }, headers: auth_headers(@token), as: :json
    assert_response :ok
    assert_in_delta Time.zone.now.to_f, @user.activity_logs.order(:id).last.created_at.to_f, 2
  end

  test "password reset verifies the single use token and revokes existing credentials" do
    raw, digest = Devise.token_generator.generate(User, :reset_password_token)
    @user.update!(reset_password_token: digest, reset_password_sent_at: Time.zone.now)
    patch "/api/v1/native/password", params: { reset_password_token: "invalid", password: "newpassword123", password_confirmation: "newpassword123" }, as: :json
    assert_response :unprocessable_entity
    assert_not @token.reload.revoked?
    patch "/api/v1/native/password", params: { reset_password_token: raw, password: "newpassword123", password_confirmation: "newpassword123" }, as: :json
    assert_response :ok
    assert @token.reload.revoked?
    assert @user.reload.valid_password?("newpassword123")
    patch "/api/v1/native/password", params: { reset_password_token: raw, password: "otherpassword123", password_confirmation: "otherpassword123" }, as: :json
    assert_response :unprocessable_entity
  end

  test "confirmation requires a valid token and association document covers email routes" do
    raw, digest = Devise.token_generator.generate(User, :confirmation_token)
    @user.update_columns(confirmed_at: nil, confirmation_token: digest, confirmation_sent_at: Time.zone.now)
    post "/api/v1/native/confirmation/verify", params: { confirmation_token: "invalid" }, as: :json
    assert_response :unprocessable_entity
    post "/api/v1/native/confirmation/verify", params: { confirmation_token: raw }, as: :json
    assert_response :ok
    assert @user.reload.confirmed?
    get "/.well-known/apple-app-site-association"
    assert_response :ok
    assert_includes response.parsed_body.dig("applinks", "details", 0, "paths"), "/users/password/edit"
  end

  test "vocabulary search matches owned translations and escapes wildcards" do
    Current.set(translation_language: languages(:english)) do
      entry = PhraseTokenUser.create_custom!(user: @user, sentence: "hola mundo", language: languages(:spanish), token_range: 1..1, translation: "world")
      get "/api/v1/native/vocabulary", params: { q: "world" }, headers: auth_headers(@token)
      assert_response :ok
      assert_equal [ entry.id ], response.parsed_body.fetch("items").map { |row| row["id"] }
      get "/api/v1/native/vocabulary", params: { q: "%" }, headers: auth_headers(@token)
      assert_response :ok
      assert_empty response.parsed_body.fetch("items")
    end
  end

  test "native course actions preserve enrollment sharing and reset semantics" do
    %w[enroll share mark_done].each do |operation|
      post "/api/v1/native/courses/#{@course.slug}/action", params: { operation: operation }, headers: auth_headers(@token), as: :json
      assert_response :ok
    end
    assert @user.sharing?(@course)
    get "/api/v1/native/courses", params: { enrolled: true }, headers: auth_headers(@token)
    assert_response :ok
    assert_equal [ @lesson.id ], response.parsed_body.dig("items", 0, "completed_lesson_ids")
    post "/api/v1/native/courses/#{@course.slug}/action", params: { operation: "reset" }, headers: auth_headers(@token), as: :json
    assert_response :ok
    assert_not @user.enrollments.exists?(course: @course)
    assert_not @user.lesson_users.exists?(lesson: @lesson)
    assert @course.reload.readable_by?(@user)
  end
end
