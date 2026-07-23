require "test_helper"
require "minitest/mock"

module App
  class CreditsControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @user = User.create!(
        email: "paypal-buttons@example.com",
        password: "password123",
        confirmed_at: Time.zone.now
      )
      sign_in @user
    end

    test "web users see sandbox payment forms for every fixed pack" do
      client = Paypal::Client.new(merchant_id: "SANDBOXMERCHANT")

      Paypal::Client.stub(:new, client) do
        get app_credits_path, headers: { "User-Agent" => "Mozilla/5.0" }
      end

      assert_response :success
      assert_select "form[action=?][method=post]", Paypal::Client::SANDBOX_URL,
                    count: Paypal::CreditPacks.all.size
      assert_select "input[name=notify_url][value=?]", request.base_url + paypal_notification_path(lang: nil),
                    count: Paypal::CreditPacks.all.size
      assert_select "input[name=business][value=SANDBOXMERCHANT]",
                    count: Paypal::CreditPacks.all.size
      assert_select "input[name=amount][value='2.99']"
      assert_select "input[name=item_number][value=credits_5]"
    end
  end
end
