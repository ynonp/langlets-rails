module Apple
  class CreditPacks
    Pack = Data.define(:id, :product_id, :credits, :price)

    PACKS = [
      Pack.new(id: "standard", product_id: "com.ynonp.langlets.credits20", credits: 20, price: "$10")
    ].index_by(&:product_id).freeze

    class << self
      def all = PACKS.values
      def fetch(product_id) = PACKS.fetch(product_id.to_s)
    end
  end
end
