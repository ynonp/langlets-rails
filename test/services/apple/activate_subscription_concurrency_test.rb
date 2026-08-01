require "test_helper"

module Apple
  # Separate class, like Credits::LedgerConcurrencyTest: transactional fixtures
  # would hide the row from the other thread's connection, so this one manages
  # its own data.
  class ActivateSubscriptionConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    ORIGINAL = "2000000999999999".freeze

    EMAIL = "sub-concurrency@example.com".freeze

    setup do
      # No transactional rollback here, so an aborted run leaves its rows behind
      # and the next one fails on the unique email rather than on what it tests.
      destroy_fixture_user!
      @user = User.create!(email: EMAIL, password: "password123", confirmed_at: Time.zone.now)
      ActivateSubscription.call(user: @user, payload: transaction(purchased_ago: 40.days, expires_in: -10.days))
    end

    teardown { destroy_fixture_user! }

    # Apple neither orders nor deduplicates notifications, and the app's restore
    # POST can land at the same moment. Both payloads read the same
    # `purchased_at`, both decide they are not stale, and without the row lock
    # whichever writes *last* wins — so an old EXPIRED can overwrite a fresh
    # DID_RENEW and the user silently loses Pro until the next notification.
    #
    # With the lock, the two apply in some serial order and the older one is
    # rejected as stale on its second look, whichever way they raced.
    test "a stale payload cannot overwrite a renewal it raced" do
      renewal = transaction(purchased_ago: 0.seconds, expires_in: 365.days)
      stale   = transaction(purchased_ago: 40.days, expires_in: -10.days)

      barrier = Concurrent::CyclicBarrier.new(2) if defined?(Concurrent::CyclicBarrier)

      threads = [ renewal, stale ].map do |payload|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier&.wait
            ActivateSubscription.call(payload: payload)
          end
        end
      end
      threads.each(&:join)

      subscription = Subscription.find_by!(original_transaction_id: ORIGINAL)
      assert_in_delta 365.days.from_now, subscription.expires_at, 60.seconds,
                      "the renewal must survive the race"
      assert subscription.status_active?
      assert @user.reload.pro?
    end

    test "concurrent deliveries of one purchase still make one subscription" do
      Subscription.where(user_id: @user.id).delete_all

      threads = 3.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ActivateSubscription.call(user: User.find(@user.id),
                                      payload: transaction(purchased_ago: 0.seconds, expires_in: 365.days))
          end
        end
      end
      threads.each(&:join)

      assert_equal 1, Subscription.where(original_transaction_id: ORIGINAL).count
    end

    private

    # destroy, not delete_all: the account owns channels, ledger entries and a
    # subscription, and only the dependent callbacks know the right order.
    def destroy_fixture_user!
      User.where(email: EMAIL).find_each(&:destroy)
    end

    def transaction(purchased_ago:, expires_in:)
      {
        "transactionId" => ORIGINAL,
        "originalTransactionId" => ORIGINAL,
        "productId" => Apple::SubscriptionPlans.yearly.product_id,
        "type" => Apple::SubscriptionPlans.transaction_type,
        "purchaseDate" => (purchased_ago.ago.to_f * 1000).round,
        "expiresDate" => (expires_in.from_now.to_f * 1000).round,
        "environment" => "Sandbox"
      }
    end
  end
end
