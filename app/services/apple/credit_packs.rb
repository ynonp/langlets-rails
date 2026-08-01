module Apple
  class CreditPacks
    Pack = Data.define(:id, :product_id, :credits, :price)

    PACKS = [
      Pack.new(id: "standard", product_id: "com.ynonp.langlets.credits20", credits: 20, price: "$10")
    ].index_by(&:product_id).freeze

    class << self
      def all = PACKS.values
      def fetch(product_id) = PACKS.fetch(product_id.to_s)

      # What StoreKit calls this kind of product. Apple::VerifyTransaction
      # compares it against the transaction's own `type`, so a subscription
      # cannot be redeemed for credits.
      def transaction_type = "Consumable"
    end
  end
end
