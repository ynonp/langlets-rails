require "test_helper"

module App
  class ProControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    NATIVE = { "User-Agent" => "LangletsNative/1.0" }.freeze

    setup do
      @user = User.create!(email: "paywall@example.com", password: "password123", confirmed_at: Time.zone.now)
      sign_in @user, scope: :user
    end

    test "the paywall offers both server-defined plans" do
      get app_pro_path(lang: "es"), headers: NATIVE

      assert_response :success
      Apple::SubscriptionPlans.all.each do |plan|
        assert_select "input[name=pro_plan][value=?]", plan.product_id
      end
      assert_select "input[name=pro_plan][checked]", 1, "exactly one plan starts selected"
      assert_select "[data-product-id=?]", Apple::SubscriptionPlans.yearly.product_id
    end

    test "the paywall posts to the subscription endpoint, never the credits one" do
      get app_pro_path(lang: "es"), headers: NATIVE

      assert_select "[data-bridge--apple-purchase-endpoint-value=?]", app_apple_subscriptions_path
      assert_select "[data-bridge--apple-purchase-endpoint-value=?]", app_apple_purchases_path, false
    end

    test "App Review's required restore control is on the paywall" do
      get app_pro_path(lang: "es"), headers: NATIVE

      assert_select "[data-action='bridge--apple-purchase#restore']"
    end

    test "an entitled user is sent to their subscription rather than the offer" do
      subscribe!

      get app_pro_path(lang: "es"), headers: NATIVE

      assert_redirected_to app_pro_success_path
    end

    test "success names the plan and its renewal date" do
      subscribe!

      get app_pro_success_path(lang: "es"), headers: NATIVE

      assert_response :success
      assert_select "h1", text: I18n.t("app.pro.success.title")
      assert_match "$100 / year", response.body
    end

    # Reaching success without an entitlement means the StoreKit sheet was
    # cancelled, or somebody navigated back into it. "You're Pro!" would be a
    # flat lie.
    test "success without an entitlement goes back to the offer" do
      get app_pro_success_path(lang: "es"), headers: NATIVE

      assert_redirected_to app_pro_path
    end

    test "the paywall is native-only" do
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
