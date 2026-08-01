require "json"
require "openssl"

module Apple
  # Authenticates a StoreKit transaction the iOS app handed to the web view, and
  # resolves the product it bought.
  #
  # The signature work lives in Apple::SignedPayload; what is left here is the
  # part that is about *us* — right app, right account, not revoked, and a
  # product we actually sell. None of those are cryptographic, and all of them
  # matter: a validly signed transaction for somebody else's account, or for a
  # product id we never offered, is exactly the shape a replay takes.
  #
  # `catalog` is the set of products the caller is willing to accept, and it is
  # what stops a $10 consumable from being redeemed as a year of Pro: each
  # endpoint passes only its own kind, so a real transaction cannot be pointed at
  # the wrong grant.
  class VerifyTransaction
    BUNDLE_ID = "com.ynonp.langlets"

    def initialize(signed_transaction:, user:, catalog: CreditPacks)
      @signed_transaction = signed_transaction
      @user = user
      @catalog = catalog
    end

    # Returns [payload, product]. Raises ArgumentError for anything else.
    def call
      payload = SignedPayload.verify!(@signed_transaction)
      product = @catalog.fetch(payload.fetch("productId"))

      raise ArgumentError, "Wrong app" unless payload["bundleId"] == BUNDLE_ID
      raise ArgumentError, "Wrong account" unless payload["appAccountToken"]&.downcase == AppAccountToken.for(@user)
      raise ArgumentError, "Revoked transaction" if payload["revocationDate"].present?
      raise ArgumentError, "Unsupported purchase type" unless payload["type"] == @catalog.transaction_type

      [ payload, product ]
    rescue KeyError, JSON::ParserError, OpenSSL::OpenSSLError, ArgumentError
      raise ArgumentError, "Invalid Apple transaction"
    end
  end
end
