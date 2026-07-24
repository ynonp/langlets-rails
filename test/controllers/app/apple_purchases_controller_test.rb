require "test_helper"

module App
  class ApplePurchasesTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @user = User.create!(
        email: "apple-purchase@example.com",
        password: "password123",
        confirmed_at: Time.zone.now
      )
      sign_in @user, scope: :user
      get app_home_path(lang: "es"), headers: { "User-Agent" => "LangletsNative/1.0" }
    end

    test "a verified transaction grants its server-defined pack once" do
      payload = {
        "transactionId" => "2000000123456789",
        "originalTransactionId" => "2000000123456789"
      }
      verifier = Object.new
      verifier.define_singleton_method(:call) do
        [ payload, Apple::CreditPacks.fetch("com.ynonp.langlets.credits20") ]
      end

      Apple::VerifyTransaction.stub(:new, ->(**) { verifier }) do
        2.times do
          post app_apple_purchases_path,
               params: { signed_transaction: "signed.transaction.value" },
               headers: { "User-Agent" => "LangletsNative/1.0" },
               as: :json
          assert_response :success
        end
      end

      assert_equal User::SIGNUP_CREDITS + 20, @user.reload.credit_balance
      entry = @user.credit_ledger_entries.find_by!(idempotency_key: "apple:2000000123456789")
      assert_equal "apple", entry.metadata["provider"]
      assert_equal "com.ynonp.langlets.credits20", entry.metadata["product_id"]
    end

    test "an invalid transaction does not grant credits" do
      verifier = Object.new
      verifier.define_singleton_method(:call) { raise ArgumentError, "invalid" }

      Apple::VerifyTransaction.stub(:new, ->(**) { verifier }) do
        post app_apple_purchases_path,
             params: { signed_transaction: "forged" },
             headers: { "User-Agent" => "LangletsNative/1.0" },
             as: :json
      end

      assert_response :unprocessable_content
      assert_equal User::SIGNUP_CREDITS, @user.reload.credit_balance
    end
  end
end
