require "base64"
require "json"
require "openssl"

module Apple
  # Decodes and authenticates one of Apple's signed JWS blobs.
  #
  # Apple uses the same envelope for two different things we care about: the
  # StoreKit transaction the app hands us after a purchase, and the payloads
  # inside an App Store Server Notification. The envelope carries its own
  # certificate chain in the `x5c` header, so authenticating it is entirely
  # offline — there is no key to fetch and no shared secret to configure. Both
  # callers need exactly the same three checks, which is why they live here
  # rather than being written twice.
  #
  #   Apple::SignedPayload.verify!(jws) # => decoded payload Hash
  #
  # Raises ArgumentError for anything that is not a payload Apple signed.
  class SignedPayload
    ROOT_COMMON_NAME_PREFIX = "Apple Root CA".freeze

    class << self
      def verify!(signed_payload)
        header_segment, payload_segment, signature_segment = signed_payload.to_s.split(".", 3)
        raise ArgumentError, "Invalid signed payload" unless signature_segment

        header = decode_json(header_segment)
        certificates = Array(header["x5c"]).map do |value|
          OpenSSL::X509::Certificate.new(Base64.strict_decode64(value))
        end

        verify_certificate_chain!(certificates)
        verify_signature!(certificates.first.public_key, "#{header_segment}.#{payload_segment}", decode(signature_segment))

        decode_json(payload_segment)
      rescue JSON::ParserError, OpenSSL::OpenSSLError, ArgumentError
        raise ArgumentError, "Invalid Apple signed payload"
      end

      # Apple sends every timestamp as milliseconds since the epoch, and omits
      # the ones that don't apply (a subscription that has not been revoked has
      # no revocationDate at all).
      def time_at(milliseconds)
        return nil if milliseconds.blank?

        Time.zone.at(milliseconds.to_i / 1000.0)
      end

      private

      def decode(value)
        Base64.urlsafe_decode64(value.ljust((value.length + 3) & ~3, "="))
      end

      def decode_json(value)
        JSON.parse(decode(value))
      end

      # Two separate guarantees, and both are needed. The chain has to verify
      # cryptographically *and* terminate at an Apple root: a self-signed chain
      # verifies against itself perfectly well, and the system trust store is
      # what makes the root claim mean something.
      def verify_certificate_chain!(certificates)
        raise ArgumentError, "Missing certificate chain" if certificates.empty?

        root_common_name = certificates.last.subject.to_a.find { |name,| name == "CN" }&.at(1)
        unless root_common_name&.start_with?(ROOT_COMMON_NAME_PREFIX)
          raise ArgumentError, "Not an Apple certificate chain"
        end

        store = OpenSSL::X509::Store.new
        store.set_default_paths
        raise ArgumentError, "Untrusted certificate" unless store.verify(certificates.first, certificates.drop(1))
      end

      # ES256 signatures are raw r||s; OpenSSL wants them DER-encoded.
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
end
