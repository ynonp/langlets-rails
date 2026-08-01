module Apple
  # Handles one App Store Server Notification (V2).
  #
  # This is what keeps Pro true after the first billing period. StoreKit tells us
  # about the original purchase and nothing else; every renewal, cancellation,
  # billing failure, refund and expiry afterwards arrives here. Without it a
  # yearly subscriber would silently lose Pro the moment `expires_at` passed and
  # a refunded one would keep it forever.
  #
  # The notification is a JWS wrapping another JWS: the outer one carries the
  # notification type, the inner `signedTransactionInfo` carries the same
  # transaction shape the app posts after a purchase. Both are verified — the
  # outer proves Apple sent it, the inner proves the transaction inside it wasn't
  # swapped.
  class ProcessNotification
    Result = Data.define(:status, :notification_type, :subscription)

    def self.call(...) = new(...).call

    def initialize(signed_payload:)
      @signed_payload = signed_payload
    end

    def call
      notification = SignedPayload.verify!(@signed_payload)
      data = notification["data"] || {}

      raise ArgumentError, "Wrong app" unless data["bundleId"] == VerifyTransaction::BUNDLE_ID

      signed_transaction = data["signedTransactionInfo"]
      return skipped(notification) if signed_transaction.blank?

      transaction = SignedPayload.verify!(signed_transaction)
      return skipped(notification) unless transaction["type"] == SubscriptionPlans.transaction_type

      # No `user:`. A notification identifies a subscription, not an account, and
      # the appAccountToken is a one-way HMAC — so the only way to attribute one
      # is the row the purchase itself created. An unknown subscription is
      # therefore a real (if rare) state, not an error: see the README note in
      # ActivateSubscription about restores.
      subscription = ActivateSubscription.call(payload: transaction)

      if subscription.nil?
        Rails.logger.warn(
          "Apple notification #{notification["notificationType"]} for unknown subscription " \
          "#{transaction["originalTransactionId"]}"
        )
        return Result.new(status: :unknown_subscription, notification_type: notification["notificationType"], subscription: nil)
      end

      Result.new(status: :applied, notification_type: notification["notificationType"], subscription: subscription)
    end

    private

    # Apple sends notification types we have no opinion about (consumable
    # refunds, renewal-preference changes). Acknowledging them is correct —
    # anything but a 2xx makes Apple retry for days.
    def skipped(notification)
      Result.new(status: :skipped, notification_type: notification["notificationType"], subscription: nil)
    end
  end
end
