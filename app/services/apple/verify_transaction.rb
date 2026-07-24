require "base64"
require "json"
require "openssl"

module Apple
  class VerifyTransaction
    BUNDLE_ID = "com.ynonp.langlets"

    def initialize(signed_transaction:, user:)
      @signed_transaction = signed_transaction
      @user = user
    end

    def call
      header_segment, payload_segment, signature_segment = @signed_transaction.to_s.split(".", 3)
      raise ArgumentError, "Invalid signed transaction" unless signature_segment

      header = decode_json(header_segment)
      certificates = Array(header["x5c"]).map { |value| OpenSSL::X509::Certificate.new(Base64.strict_decode64(value)) }
      verify_certificate_chain!(certificates)
      verify_signature!(certificates.first.public_key, "#{header_segment}.#{payload_segment}", decode(signature_segment))

      payload = decode_json(payload_segment)
      pack = CreditPacks.fetch(payload.fetch("productId"))
      raise ArgumentError, "Wrong app" unless payload["bundleId"] == BUNDLE_ID
      raise ArgumentError, "Wrong account" unless payload["appAccountToken"]&.downcase == AppAccountToken.for(@user)
      raise ArgumentError, "Revoked transaction" if payload["revocationDate"].present?
      raise ArgumentError, "Unsupported purchase type" unless payload["type"] == "Consumable"

      [ payload, pack ]
    rescue KeyError, JSON::ParserError, OpenSSL::OpenSSLError, ArgumentError
      raise ArgumentError, "Invalid Apple transaction"
    end

    private

    def decode(value)
      Base64.urlsafe_decode64(value.ljust((value.length + 3) & ~3, "="))
    end

    def decode_json(value)
      JSON.parse(decode(value))
    end

    def verify_certificate_chain!(certificates)
      raise ArgumentError, "Missing certificate chain" if certificates.empty?
      root_common_name = certificates.last.subject.to_a.find { |name,| name == "CN" }&.at(1)
      raise ArgumentError, "Not an Apple certificate chain" unless root_common_name&.start_with?("Apple Root CA")

      store = OpenSSL::X509::Store.new
      store.set_default_paths
      raise ArgumentError, "Untrusted certificate" unless store.verify(certificates.first, certificates.drop(1))
    end

    def verify_signature!(public_key, data, raw_signature)
      raise ArgumentError, "Invalid signature" unless raw_signature.bytesize == 64

      r, s = raw_signature.unpack("a32a32").map { |part| OpenSSL::BN.new(part, 2) }
      signature = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::Integer(r),
        OpenSSL::ASN1::Integer(s)
      ]).to_der
      raise ArgumentError, "Invalid signature" unless public_key.verify(OpenSSL::Digest::SHA256.new, signature, data)
    end
  end
end
