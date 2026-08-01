require "test_helper"

module App
  class AppleSubscriptionsControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    NATIVE = { "User-Agent" => "LangletsNative/1.0" }.freeze
    ORIGINAL = "2000000333333333".freeze

    setup do
      @user = User.create!(email: "subscribe@example.com", password: "password123", confirmed_at: Time.zone.now)
      sign_in @user, scope: :user
      get app_home_path(lang: "es"), headers: NATIVE
    end

    test "a verified subscription transaction entitles Pro and points at the confirmation" do
      post_transaction(payload: transaction)

      assert_response :success
      assert_equal app_pro_success_path, response.parsed_body["redirect"]
      assert @user.reload.pro?
    end

    test "delivering the same transaction twice leaves one subscription" do
      2.times { post_transaction(payload: transaction) }

      assert_equal 1, @user.subscriptions.count
    end

    test "an expired transaction is refused rather than celebrated" do
      post_transaction(payload: transaction(expires_in: -1.day))

      assert_response :unprocessable_content
      assert_not @user.reload.pro?
    end

    test "an unverifiable transaction grants nothing" do
      verifier = Object.new
      verifier.define_singleton_method(:call) { raise ArgumentError, "invalid" }

      Apple::VerifyTransaction.stub(:new, ->(**) { verifier }) do
        post app_apple_subscriptions_path,
             params: { signed_transaction: "forged" },
             headers: NATIVE, as: :json
      end

      assert_response :unprocessable_content
      assert_not @user.reload.pro?
    end

    # The catalog argument is the thing that keeps the two purchase endpoints
    # apart; without it a $10 consumable would buy a year of Pro.
    test "the subscription endpoint only accepts the subscription catalog" do
      seen = nil
      verifier = Object.new
      verifier.define_singleton_method(:call) { [ {}, nil ] }

      Apple::VerifyTransaction.stub(:new, ->(**kwargs) { seen = kwargs[:catalog]; verifier }) do
        post app_apple_subscriptions_path,
             params: { signed_transaction: "x" }, headers: NATIVE, as: :json
      end

      assert_equal Apple::SubscriptionPlans, seen
    end

    private

    def transaction(expires_in: 365.days)
      {
        "transactionId" => ORIGINAL,
        "originalTransactionId" => ORIGINAL,
        "productId" => Apple::SubscriptionPlans.yearly.product_id,
        "type" => Apple::SubscriptionPlans.transaction_type,
        "purchaseDate" => (Time.zone.now.to_f * 1000).round,
        "expiresDate" => (expires_in.from_now.to_f * 1000).round,
        "environment" => "Sandbox"
      }
    end

    def post_transaction(payload:)
      plan = Apple::SubscriptionPlans.yearly
      verifier = Object.new
      verifier.define_singleton_method(:call) { [ payload, plan ] }

      Apple::VerifyTransaction.stub(:new, ->(**) { verifier }) do
        post app_apple_subscriptions_path,
             params: { signed_transaction: "signed.transaction.value" },
             headers: NATIVE, as: :json
      end
    end
  end
end
