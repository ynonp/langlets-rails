require "net/http"

module Paypal
  class Client
    class NotConfigured < StandardError; end
    class VerificationUnavailable < StandardError; end

    SANDBOX_URL = "https://www.sandbox.paypal.com/cgi-bin/webscr"
    LIVE_URL = "https://www.paypal.com/cgi-bin/webscr"

    attr_reader :merchant_id

    def initialize(merchant_id: Rails.application.credentials.dig(:paypal, :merchant_id))
      @merchant_id = merchant_id.to_s
    end

    def configured? = merchant_id.present?
    def checkout_url = sandbox? ? SANDBOX_URL : LIVE_URL

    def purchase_token(user:, pack:)
      Rails.application.message_verifier("paypal-credit-purchase").generate(
        { user_id: user.id, pack_id: pack.id },
        purpose: "paypal-credit-purchase"
      )
    end

    def decode_purchase_token(token)
      Rails.application.message_verifier("paypal-credit-purchase").verified(
        token,
        purpose: "paypal-credit-purchase"
      )&.with_indifferent_access
    end

    # IPN has no shared webhook secret. PayPal authenticates a notification by
    # requiring the listener to post its exact raw body back with this command.
    def verify_ipn(raw_body)
      raise NotConfigured, "paypal merchant_id is not configured" unless configured?

      uri = URI(checkout_url)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request.body = "cmd=_notify-validate&#{raw_body}"

      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: true,
        open_timeout: 5,
        read_timeout: 10
      ) { |http| http.request(request) }

      raise VerificationUnavailable, "PayPal IPN verification returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body.to_s.strip == "VERIFIED"
    rescue IOError, SocketError, SystemCallError, Timeout::Error => e
      raise VerificationUnavailable, e.message
    end

    private

    def sandbox? = !Rails.env.production?
  end
end
