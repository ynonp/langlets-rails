module Paypal
  class CreditPacks
    Pack = Data.define(:id, :credits, :price_cents) do
      def item_number = "credits_#{credits}"
      def price = format("%.2f", price_cents / 100.0)
    end

    PACKS = [
      Pack.new(id: "starter", credits: 5, price_cents: 299),
      Pack.new(id: "popular", credits: 15, price_cents: 699),
      Pack.new(id: "standard", credits: 20, price_cents: 1000),
      Pack.new(id: "value", credits: 40, price_cents: 1499)
    ].index_by(&:id).freeze

    class << self
      def all = PACKS.values
      def fetch(id) = PACKS.fetch(id.to_s)
    end
  end
end
