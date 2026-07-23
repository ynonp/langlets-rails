require "test_helper"
require "minitest/mock"

class PaypalNotificationsControllerTest < ActionDispatch::IntegrationTest
  test "the public IPN endpoint accepts a processed notification without CSRF" do
    result = Paypal::ProcessNotification::Result.new(status: :credited, ledger_entry: nil)

    Paypal::ProcessNotification.stub(:call, result) do
      post paypal_notification_path, params: "payment_status=Completed",
           headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }
    end

    assert_response :ok
  end

  test "a temporary PayPal verification failure asks PayPal to retry" do
    failure = ->(**) { raise Paypal::Client::VerificationUnavailable, "timeout" }

    Paypal::ProcessNotification.stub(:call, failure) do
      post paypal_notification_path, params: "payment_status=Completed",
           headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }
    end

    assert_response :bad_gateway
  end
end
