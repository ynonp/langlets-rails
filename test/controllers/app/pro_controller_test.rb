require "test_helper"

module App
  class ProControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    NATIVE = { "User-Agent" => "LangletsNative/1.0" }.freeze

    setup do
      @user = User.create!(email: "paywall@example.com", password: "password123", confirmed_at: Time.zone.now)
      sign_in @user, scope: :user
    end

    test "the Pro screen links out to the Discord invite" do
      get app_pro_path(lang: "es"), headers: NATIVE

      assert_response :success
      assert_select "a[href=?]", App::ProController::DISCORD_INVITE_URL
    end

    test "the Pro screen is available on Android too, since there is nothing left to purchase" do
      get app_pro_path(lang: "es"), headers: { "User-Agent" => "LangletsNative/1.0 (Android)" }

      assert_response :success
      assert_select "a[href=?]", App::ProController::DISCORD_INVITE_URL
    end

    test "an entitled user is sent to their subscription rather than the offer" do
      subscribe!

      get app_pro_path(lang: "es"), headers: NATIVE

      assert_redirected_to app_pro_success_path
    end

    test "success points a real Apple subscriber to App Store Settings" do
      subscribe!

      get app_pro_success_path(lang: "es"), headers: NATIVE

      assert_response :success
      assert_select "h1", text: I18n.t("app.pro.success.title")
      assert_match I18n.t("app.pro.success.manage"), response.body
    end

    test "success does not point a console-granted user to App Store Settings" do
      @user.pro!

      get app_pro_success_path(lang: "es"), headers: NATIVE

      assert_response :success
      assert_no_match I18n.t("app.pro.success.manage"), response.body
    end

    # Reaching success without an entitlement means nobody has granted Pro yet,
    # or a stale back-navigation. "You're Pro!" would be a flat lie.
    test "success without an entitlement goes back to the offer" do
      get app_pro_success_path(lang: "es"), headers: NATIVE

      assert_redirected_to app_pro_path
    end

    test "the Pro screen is native-only" do
      get app_pro_path(lang: "es")

      assert_redirected_to root_path
    end

    private

    def subscribe!
      Subscription.create!(
        user: @user,
        product_id: Apple::SubscriptionPlans.yearly.product_id,
        plan: :yearly,
        status: :active,
        original_transaction_id: "2000000222222222",
        purchased_at: Time.zone.now,
        expires_at: 1.year.from_now
      )
    end
  end
end
