require "test_helper"

module App
  class DeviceTokensControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    NATIVE = { "User-Agent" => "LangletsNative/2.0" }.freeze
    WEB = { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" }.freeze
    TOKEN = "a" * 64

    setup do
      @user = User.create!(email: "device-api@example.com", password: "password123", confirmed_at: Time.zone.now)
      new_user_session_path # Load Devise's lazy route mapping before sign_in.
      sign_in @user
      get "/app?lang=es", headers: NATIVE # seeds session[:lang]
    end

    test "registers a device against the signed-in user" do
      post app_device_tokens_path,
           params: { token: TOKEN, environment: "sandbox", app_version: "2.0" },
           headers: NATIVE

      assert_response :success
      device = @user.device_tokens.sole
      assert_equal TOKEN, device.token
      assert_equal "sandbox", device.environment
      assert_equal "2.0", device.app_version
    end

    test "requires a token" do
      post app_device_tokens_path, params: {}, headers: NATIVE

      assert_response :unprocessable_entity
      assert_equal 0, @user.device_tokens.count
    end

    # A debug build and an App Store build get different tokens valid against
    # different APNs hosts; anything unrecognised is safer as production.
    test "an unknown environment falls back to production" do
      post app_device_tokens_path, params: { token: TOKEN, environment: "staging" }, headers: NATIVE

      assert_response :success
      assert_equal "production", @user.device_tokens.sole.environment
    end

    test "registering twice does not duplicate" do
      2.times { post app_device_tokens_path, params: { token: TOKEN }, headers: NATIVE }

      assert_equal 1, @user.device_tokens.count
    end

    test "requires a signed-in user" do
      sign_out @user

      post app_device_tokens_path, params: { token: TOKEN }, headers: NATIVE

      assert_redirected_to new_user_session_path(returnto: "/app/device_tokens?lang=es")
      assert_equal 0, DeviceToken.count
    end

    test "is native-only" do
      post app_device_tokens_path, params: { token: TOKEN }, headers: WEB

      assert_redirected_to root_path
      assert_equal 0, DeviceToken.count
    end
  end

  class PushPromptTimingTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    NATIVE = { "User-Agent" => "LangletsNative/2.0" }.freeze

    setup do
      @user = User.create!(email: "prompt@example.com", password: "password123", confirmed_at: Time.zone.now)
      new_user_session_path # Load Devise's lazy route mapping before sign_in.
      sign_in @user
      get "/app?lang=es", headers: NATIVE
    end

    # iOS gives you one shot at the prompt per install; a "Don't Allow" is
    # effectively permanent. Asking before the app has done anything for the user
    # is how you earn one.
    test "does not ask a user who has never imported anything" do
      get "/app", headers: NATIVE

      assert_response :success
      assert_select "[data-bridge--push-ask-value='false']"
    end

    test "asks once the user has an import worth being told about" do
      @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=kJQP7kiw5Fk", youtube_video_id: "kJQP7kiw5Fk",
        clip_language: "Spanish", translation_language: "English", status: :importing, charged: true
      )

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "[data-bridge--push-ask-value='true']"
    end

    test "does not ask on the strength of a cancelled import alone" do
      @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=kJQP7kiw5Fk", youtube_video_id: "kJQP7kiw5Fk",
        clip_language: "Spanish", translation_language: "English", status: :canceled, charged: true
      )

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "[data-bridge--push-ask-value='false']"
    end

    # Silent registration still has to happen every launch, or a token that
    # rotates never reaches us.
    test "the bridge element renders even when not asking" do
      get "/app", headers: NATIVE

      assert_select "[data-controller='bridge--push']"
      assert_select "[data-bridge--push-endpoint-value=?]", app_device_tokens_path
    end
  end
end
