# One Langlets Pro subscription, mirrored from Apple.
#
# The source of truth is Apple, not this table: StoreKit tells us about the
# original purchase and App Store Server Notifications tell us about every
# renewal, cancellation, refund and expiry after it. This row is the local cache
# that `User#pro?` can read on every request without a network call.
#
# Keyed on original_transaction_id — the identifier Apple keeps stable across a
# subscription's whole life — so a renewal updates the purchase it renews.
class Subscription < ApplicationRecord
  belongs_to :user

  # The offer the user picked. Persisted as an integer; keep the values stable.
  enum :plan, { monthly: 0, yearly: 1 }, prefix: true

  # `active` is Apple's happy path *and* its billing-retry grace period: the
  # subscription has not been cancelled, and entitlement is decided by
  # expires_at. `expired` and `revoked` are terminal until the user resubscribes,
  # and revoked additionally means Apple refunded the purchase.
  enum :status, { active: 0, expired: 1, revoked: 2 }, prefix: true

  validates :product_id, :original_transaction_id, presence: true

  # Everything that entitles someone to Pro right now. Written as a scope rather
  # than a Ruby predicate because Home, the paywall and the import path all ask
  # the same question and it must be one definition.
  scope :entitling, -> { status_active.where(expires_at: Time.zone.now..) }

  def entitling?
    status_active? && expires_at.present? && expires_at.future?
  end

  # What the App Store shows the user, so support can match a receipt to a row.
  def apple_plan
    Apple::SubscriptionPlans.find(product_id)
  end
end
