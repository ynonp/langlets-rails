require "test_helper"

# The listener that keeps Pro true after the first billing period.
#
# The signature itself is Apple::SignedPayload's job and cannot be exercised
# end to end here — a chain that verifies against the system trust store is
# something only Apple can produce. What is tested here is everything around it:
# that an unsigned payload is refused outright, and that a payload Apple did sign
# reaches the subscription it names.
class AppleNotificationsControllerTest < ActionDispatch::IntegrationTest
  ORIGINAL = "2000000444444444".freeze

  setup do
    @user = User.create!(email: "renewals@example.com", password: "password123", confirmed_at: Time.zone.now)
    @subscription = Subscription.create!(
      user: @user,
      product_id: Apple::SubscriptionPlans.monthly.product_id,
      plan: :monthly, status: :active,
      original_transaction_id: ORIGINAL,
      purchased_at: 1.month.ago, expires_at: 1.hour.from_now
    )
  end

  test "a forged notification is refused and changes nothing" do
    post apple_notifications_path, params: { signedPayload: "not.a.jws" }, as: :json

    assert_response :bad_request
    assert_in_delta 1.hour.from_now, @subscription.reload.expires_at, 5.seconds
  end

  test "a missing payload is refused" do
    post apple_notifications_path, params: {}, as: :json

    assert_response :bad_request
  end

  test "a renewal extends the subscription it names" do
    deliver("DID_RENEW", transaction(expires_in: 31.days))

    assert_response :ok
    assert_in_delta 31.days.from_now, @subscription.reload.expires_at, 5.seconds
    assert @user.reload.pro?
  end

  test "an expiry ends the entitlement" do
    deliver("EXPIRED", transaction(expires_in: -1.minute))

    assert_response :ok
    assert @subscription.reload.status_expired?
    assert_not @user.reload.pro?
  end

  test "a refund revokes the entitlement" do
    deliver("REFUND", transaction(expires_in: 20.days, revoked: true))

    assert_response :ok
    assert @subscription.reload.status_revoked?
    assert_not @user.reload.pro?
  end

  # Apple retries any non-2xx for days, and no retry can turn a notification for
  # somebody else's installation into one we can attribute.
  test "a notification for an unknown subscription is acknowledged, not retried" do
    deliver("DID_RENEW", transaction(expires_in: 31.days).merge("originalTransactionId" => "9999999999"))

    assert_response :ok
    assert_equal 1, Subscription.count
  end

  test "a notification from another app is refused" do
    deliver("DID_RENEW", transaction(expires_in: 31.days), bundle_id: "com.example.other")

    assert_response :bad_request
    assert_in_delta 1.hour.from_now, @subscription.reload.expires_at, 5.seconds
  end

  private

  def transaction(expires_in:, revoked: false)
    {
      "transactionId" => "2000000444444445",
      "originalTransactionId" => ORIGINAL,
      "productId" => Apple::SubscriptionPlans.monthly.product_id,
      "type" => Apple::SubscriptionPlans.transaction_type,
      "purchaseDate" => (Time.zone.now.to_f * 1000).round,
      "expiresDate" => (expires_in.from_now.to_f * 1000).round,
      "environment" => "Production"
    }.tap { |t| t["revocationDate"] = (Time.zone.now.to_f * 1000).round if revoked }
  end

  # Stands in for Apple's signature: every blob the controller hands to
  # SignedPayload is answered with the object it would have decoded.
  def deliver(notification_type, transaction, bundle_id: Apple::VerifyTransaction::BUNDLE_ID)
    notification = {
      "notificationType" => notification_type,
      "version" => "2.0",
      "data" => {
        "bundleId" => bundle_id,
        "environment" => transaction["environment"],
        "signedTransactionInfo" => "signed-transaction"
      }
    }
    decoded = { "signed-notification" => notification, "signed-transaction" => transaction }

    Apple::SignedPayload.stub(:verify!, ->(jws) { decoded.fetch(jws) }) do
      post apple_notifications_path, params: { signedPayload: "signed-notification" }, as: :json
    end
  end
end
