# One immutable row per credit movement. Never write these directly — go through
# Credits::Ledger, which keeps them in step with users.credit_balance inside a
# single transaction.
class CreditLedgerEntry < ApplicationRecord
  belongs_to :user
  belongs_to :subject, polymorphic: true, optional: true

  # iap_purchase is reserved while StoreKit is deferred, so adding purchases later
  # doesn't renumber the existing values.
  enum :reason, {
    signup_grant: 0,
    import_spend: 1,
    import_refund: 2,
    iap_purchase: 3,
    admin_adjustment: 4,
    promo_grant: 5
  }

  validates :amount, presence: true
  validates :balance_after, presence: true
  validates :idempotency_key, presence: true

  scope :spends,  -> { where("amount < 0") }
  scope :credits, -> { where("amount > 0") }

  # Append-only. New records still save (persisted? is false until then); once
  # written, an entry can never be edited.
  def readonly?
    persisted?
  end

  before_destroy do
    raise ActiveRecord::ReadOnlyRecord, "credit ledger entries are immutable"
  end
end
