module Apple
  # Writes one verified Apple subscription transaction into the local
  # `subscriptions` cache.
  #
  # Called from two places that must not disagree: the purchase/restore endpoint
  # (where we know the user) and the App Store Server Notification handler (where
  # we don't, and match on the subscription's original transaction instead).
  #
  # Two properties do the work:
  #
  #   * **Keyed on originalTransactionId.** Apple keeps it stable for the life of
  #     a subscription, so a renewal a year from now updates the row it renews
  #     rather than appending a second entitlement.
  #   * **Ordered by the transaction's own purchase date**, not by the expiry it
  #     claims and not by arrival. Notifications are not guaranteed to arrive in
  #     order and StoreKit will happily hand the app a months-old cached
  #     transaction, so "newest wins" has to be a property of the payload. Each
  #     renewal in a chain has a later purchaseDate than the one before it; a
  #     notification *about* the transaction we already hold (EXPIRED,
  #     DID_FAIL_TO_RENEW) carries the same date and is applied, which is what
  #     lets an entitlement legitimately end early. Only a genuinely older
  #     transaction is ignored — and even then a revocation still lands, because
  #     a refund is authoritative whenever it arrives.
  class ActivateSubscription
    def self.call(...) = new(...).call

    def initialize(payload:, user: nil)
      @payload = payload
      @user = user
    end

    # Returns the Subscription, or nil when the payload belongs to a
    # subscription this installation has never seen and no user was supplied.
    def call
      return nil if original_transaction_id.blank?

      if (subscription = Subscription.find_by(original_transaction_id: original_transaction_id))
        return apply_locked!(subscription)
      end

      return nil if @user.nil?

      # No row to lock yet; the unique index is what arbitrates a race here, and
      # the rescue below picks up whichever write lost.
      subscription = Subscription.new(user: @user, original_transaction_id: original_transaction_id)
      apply!(subscription)
      subscription
    rescue ActiveRecord::RecordNotUnique
      # Two devices, or a notification racing the purchase POST. The other write
      # created the row; re-run against it so the newer payload still wins.
      apply_locked!(Subscription.find_by!(original_transaction_id: original_transaction_id))
    end

    # The staleness rule is a read-check-write, and it decides whether a payload
    # is allowed to overwrite the row. Apple does not guarantee notification
    # ordering, retries them, and the app's restore POST can land at the same
    # moment — so without the row lock two payloads can both read the same
    # `purchased_at`, both conclude they are current, and the *older* one win by
    # writing last. That loses a renewal, and the user loses Pro until the next
    # notification happens to arrive.
    #
    # with_lock reloads inside the transaction, so the comparison below reads
    # committed state rather than what we happened to fetch a moment ago.
    def apply_locked!(subscription)
      subscription.with_lock { apply!(subscription) }
      subscription
    end

    private

    def original_transaction_id = @payload["originalTransactionId"].presence

    def apply!(subscription)
      # Read *before* this payload is applied: "you're a Pro subscriber now" is
      # only true on the transition into entitlement. A renewal arrives every
      # month with the same status and must stay silent, while a lapsed
      # subscriber who comes back is genuinely news again.
      was_entitling = subscription.persisted? && subscription.entitling?

      expires_at = SignedPayload.time_at(@payload["expiresDate"])
      purchased_at = SignedPayload.time_at(@payload["purchaseDate"])
      revoked = @payload["revocationDate"].present?

      # A refund lands whenever Apple decides; everything else has to be at least
      # as recent as what we already hold, so a replayed old transaction cannot
      # rewrite a current entitlement.
      stale = !revoked && subscription.persisted? && subscription.purchased_at.present? &&
              purchased_at.present? && purchased_at < subscription.purchased_at
      return subscription if stale

      subscription.product_id = @payload["productId"]
      subscription.plan = plan_for(@payload["productId"])
      subscription.latest_transaction_id = @payload["transactionId"]
      subscription.purchased_at = purchased_at || subscription.purchased_at
      subscription.expires_at = expires_at if expires_at.present?
      subscription.environment = @payload["environment"] || subscription.environment
      # An auto-renewable transaction always carries expiresDate, and both entry
      # points reject anything that is not one — so a row with no expiry at all
      # means something we do not understand. It cannot grant Pro either way
      # (`entitling` compares `expires_at >= now`, and NULL never matches), but
      # calling it `active` would put a row in the table that says "active" and
      # entitles nothing. Since keeping `status` honest is now this column's only
      # job, say expired instead.
      subscription.status = if revoked
        :revoked
      elsif subscription.expires_at.blank? || subscription.expires_at.past?
        :expired
      else
        :active
      end

      # Nothing else to write. Library access is derived from this row through
      # ProChannel.owned_grant, so there is no second record to keep in step and
      # no window in which the two could disagree.
      subscription.save!

      notify_activated!(subscription) if subscription.entitling? && !was_entitling
      subscription
    end

    # Telling the user must never cost them the subscription: the row is
    # committed by the time this runs, and Pro is derived from the row.
    def notify_activated!(subscription)
      Notifications.deliver(user: subscription.user, kind: :pro_activated)
    rescue StandardError => e
      Rails.logger.error "Pro activation notification failed for subscription #{subscription.id}: #{e.message}"
    end

    # Products we no longer sell still have to load, so fall back on the period
    # rather than raising: the row's job is to record what the user bought.
    def plan_for(product_id)
      plan = SubscriptionPlans.find(product_id)
      return :monthly if plan.nil?

      plan.period_months >= 12 ? :yearly : :monthly
    end
  end
end
