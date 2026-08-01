module Apple
  # The Langlets Pro offers — the only thing Langlets sells. Defined on the
  # server because the browser never gets to say what something costs or what it
  # grants. The paywall renders these; App::AppleSubscriptionsController accepts
  # a transaction only for a product id that appears here.
  #
  # Each product_id must exist in App Store Connect as an **auto-renewable
  # subscription** in one group, at the matching price tier:
  #
  #   com.ynonp.langlets.pro.monthly — $10 / month
  #   com.ynonp.langlets.pro.yearly  — $100 / year
  #
  # The prices below are display copy. StoreKit is the authority on what the user
  # is actually charged and in which currency, so these strings are US pricing
  # shown before the App Store sheet opens; the sheet itself always shows the
  # localized price. Keep them in step with App Store Connect.
  class SubscriptionPlans
    Plan = Data.define(:id, :product_id, :price, :period_months, :price_cents) do
      # "$8.33" — the yearly plan's monthly equivalent, computed rather than
      # written down so the two numbers cannot drift apart.
      def monthly_equivalent
        format("$%.2f", price_cents / 100.0 / period_months)
      end
    end

    PLANS = [
      Plan.new(id: "yearly", product_id: "com.ynonp.langlets.pro.yearly",
               price: "$100", period_months: 12, price_cents: 10_000),
      Plan.new(id: "monthly", product_id: "com.ynonp.langlets.pro.monthly",
               price: "$10", period_months: 1, price_cents: 1_000)
    ].freeze

    BY_PRODUCT_ID = PLANS.index_by(&:product_id).freeze

    class << self
      def all = PLANS
      def monthly = BY_PRODUCT_ID.fetch("com.ynonp.langlets.pro.monthly")
      def yearly = BY_PRODUCT_ID.fetch("com.ynonp.langlets.pro.yearly")

      def fetch(product_id) = BY_PRODUCT_ID.fetch(product_id.to_s)

      # Nil rather than raising, for the display paths: a Subscription row can
      # outlive a product we stopped selling, and a support screen should still
      # render it.
      def find(product_id) = BY_PRODUCT_ID[product_id.to_s]

      def transaction_type = "Auto-Renewable Subscription"

      # How much the yearly plan saves against paying monthly, as a whole
      # percent — the "SAVE 17%" badge on the paywall.
      def yearly_savings_percent
        monthly_total = monthly.price_cents * yearly.period_months
        (100.0 * (monthly_total - yearly.price_cents) / monthly_total).round
      end
    end
  end
end
