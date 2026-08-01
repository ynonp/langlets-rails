require "test_helper"

module Apple
  class ActivateSubscriptionTest < ActiveSupport::TestCase
    YEARLY = Apple::SubscriptionPlans.yearly.product_id
    MONTHLY = Apple::SubscriptionPlans.monthly.product_id
    ORIGINAL = "2000000111111111".freeze

    setup do
      @user = User.create!(email: "sub@example.com", password: "password123", confirmed_at: Time.zone.now)
    end

    test "records a first purchase and entitles the user" do
      subscription = ActivateSubscription.call(payload: transaction(expires_in: 365.days), user: @user)

      assert subscription.entitling?
      assert subscription.plan_yearly?
      assert_equal ORIGINAL, subscription.original_transaction_id
      assert_equal "Sandbox", subscription.environment
      assert @user.reload.pro?
    end

    # The whole reason originalTransactionId is the key: a year from now the
    # renewal has to extend this row, not add a second entitlement next to it.
    test "a renewal extends the same subscription instead of creating another" do
      ActivateSubscription.call(payload: transaction(expires_in: 30.days), user: @user)

      renewed = ActivateSubscription.call(
        payload: transaction(expires_in: 60.days, transaction_id: "2000000111111112")
      )

      assert_equal 1, Subscription.count
      assert_equal "2000000111111112", renewed.latest_transaction_id
      assert_in_delta 60.days.from_now, renewed.expires_at, 5.seconds
    end

    # StoreKit hands the app whatever it has cached, and notifications arrive out
    # of order. An older transaction in the chain must not overwrite a newer one.
    test "an older transaction never overwrites a newer one" do
      ActivateSubscription.call(payload: transaction(expires_in: 60.days), user: @user)

      ActivateSubscription.call(payload: transaction(expires_in: 30.days, purchased_ago: 40.days))

      assert_in_delta 60.days.from_now, Subscription.sole.expires_at, 5.seconds
      assert @user.reload.pro?
    end

    # An EXPIRED or DID_FAIL_TO_RENEW notification is *about* the transaction we
    # already hold: same purchase date, expiry now in the past. Ordering must let
    # it through, or a cancelled subscriber keeps Pro forever.
    test "an expiry notification for the transaction on file ends the entitlement" do
      ActivateSubscription.call(payload: transaction(expires_in: 1.hour), user: @user)

      travel 2.hours do
        ActivateSubscription.call(payload: transaction(expires_in: -1.hour))

        assert Subscription.sole.status_expired?
        assert_not @user.reload.pro?
      end
    end

    # A refund is authoritative whenever it lands, which is exactly the case the
    # ordering rule above must not swallow.
    test "a revocation applies even when it arrives on an older transaction" do
      ActivateSubscription.call(payload: transaction(expires_in: 60.days), user: @user)

      ActivateSubscription.call(
        payload: transaction(expires_in: 30.days, purchased_ago: 40.days, revoked: true)
      )

      assert Subscription.sole.status_revoked?
      assert_not @user.reload.pro?
    end

    test "an expiry already in the past lands as expired" do
      subscription = ActivateSubscription.call(payload: transaction(expires_in: -1.day), user: @user)

      assert subscription.status_expired?
      assert_not @user.reload.pro?
    end

    test "an upgrade from monthly to yearly is recorded on the same row" do
      ActivateSubscription.call(payload: transaction(expires_in: 30.days, product_id: MONTHLY), user: @user)

      upgraded = ActivateSubscription.call(payload: transaction(expires_in: 365.days, product_id: YEARLY))

      assert_equal 1, Subscription.count
      assert upgraded.plan_yearly?
      assert_equal YEARLY, upgraded.product_id
    end

    # A notification for a subscription bought against another installation of
    # this app has nothing here to attach to, and there is no way back from an
    # appAccountToken to an account. Returning nil is the honest answer.
    test "an unknown subscription with no user is ignored rather than orphaned" do
      assert_nil ActivateSubscription.call(payload: transaction(expires_in: 30.days))
      assert_equal 0, Subscription.count
    end

    private

    def transaction(expires_in:, product_id: YEARLY, transaction_id: ORIGINAL, revoked: false, purchased_ago: 0.seconds)
      {
        "transactionId" => transaction_id,
        "originalTransactionId" => ORIGINAL,
        "productId" => product_id,
        "type" => Apple::SubscriptionPlans.transaction_type,
        "purchaseDate" => (purchased_ago.ago.to_f * 1000).round,
        "expiresDate" => (expires_in.from_now.to_f * 1000).round,
        "environment" => "Sandbox"
      }.tap do |payload|
        payload["revocationDate"] = (Time.zone.now.to_f * 1000).round if revoked
      end
    end
  end
end
