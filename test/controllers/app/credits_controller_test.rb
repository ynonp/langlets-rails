require "test_helper"
require "minitest/mock"

module App
  class CreditsScreenTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @user = User.create!(
        email: "paypal-buttons@example.com",
        password: "password123",
        confirmed_at: Time.zone.now
      )
      sign_in @user, scope: :user
      get app_home_path(lang: "es"), headers: { "User-Agent" => "LangletsNative/1.0" }
    end

    test "native users see Apple purchase buttons" do
      get app_credits_path, headers: { "User-Agent" => "LangletsNative/1.0" }

      assert_response :success
      assert_select "[data-controller='bridge--apple-purchase']", count: 1
      assert_select "button[data-action='click->bridge--apple-purchase#purchase']",
                    count: Apple::CreditPacks.all.size
      assert_select "button[data-product-id='com.ynonp.langlets.credits20']", count: 1
      assert_select "button", text: /\$10 · 20 credits/
      assert_no_match "PayPal", response.body
    end
  end
end
