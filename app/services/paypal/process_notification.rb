module Paypal
  class ProcessNotification
    Result = Data.define(:status, :ledger_entry)

    def self.call(raw_body:, client: Client.new)
      new(raw_body:, client:).call
    end

    def initialize(raw_body:, client:)
      @raw_body = raw_body
      @client = client
    end

    def call
      return result(:invalid) unless client.verify_ipn(raw_body)

      attributes = Rack::Utils.parse_nested_query(raw_body)
      return result(:ignored) unless attributes["payment_status"] == "Completed"
      return result(:invalid) unless secure_match?(attributes["receiver_id"], client.merchant_id)

      token = client.decode_purchase_token(attributes["custom"])
      return result(:invalid) unless token

      pack = CreditPacks.fetch(token[:pack_id])
      return result(:invalid) unless valid_purchase?(attributes, pack)

      user = User.find_by(id: token[:user_id])
      return result(:invalid) unless user

      ledger_entry = Credits::Ledger.grant!(
        user:,
        amount: pack.credits,
        reason: :iap_purchase,
        idempotency_key: "paypal:#{attributes.fetch('txn_id')}",
        metadata: {
          provider: "paypal",
          transaction_id: attributes["txn_id"],
          pack_id: pack.id,
          gross: attributes["mc_gross"],
          currency: attributes["mc_currency"],
          payer_id: attributes["payer_id"]
        }
      )

      return result(:invalid) unless ledger_entry.user_id == user.id

      result(:credited, ledger_entry)
    rescue KeyError, ActiveSupport::MessageVerifier::InvalidSignature
      result(:invalid)
    end

    private

    attr_reader :raw_body, :client

    def valid_purchase?(attributes, pack)
      attributes["txn_id"].present? &&
        attributes["item_number"] == pack.item_number &&
        attributes["mc_currency"] == "USD" &&
        decimal(attributes["mc_gross"]) == decimal(pack.price)
    end

    def decimal(value)
      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end

    def secure_match?(provided, expected)
      return false if provided.blank? || expected.blank?
      return false unless provided.bytesize == expected.bytesize

      ActiveSupport::SecurityUtils.secure_compare(provided, expected)
    end

    def result(status, ledger_entry = nil)
      Result.new(status:, ledger_entry:)
    end
  end
end
