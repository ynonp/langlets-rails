# HMAC-SHA256 authentication for traffic between Rails and the Create Song
# pipeline service (see pipeline/src/hmac.ts — the two must stay in sync).
# Used in both directions: verifying the pipeline's callback requests, and
# signing the trigger requests we send to it. The signature covers
# "#{timestamp}.#{body}" so a captured request can't be replayed outside the
# allowed clock skew.
module PipelineHmac
  SIGNATURE_HEADER = "X-Pipeline-Signature"
  TIMESTAMP_HEADER = "X-Pipeline-Timestamp"
  MAX_CLOCK_SKEW = 5.minutes

  module_function

  def secret
    ENV["PIPELINE_HMAC_SECRET"].presence ||
      Rails.application.credentials.dig(:pipeline_hmac_secret)
  end

  def sign(timestamp, body, secret: self.secret)
    raise ArgumentError, "PIPELINE_HMAC_SECRET is not configured" if secret.blank?

    OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")
  end

  def verify(timestamp, body, signature, secret: self.secret, now: Time.current)
    return false if secret.blank? || signature.blank?

    ts = Integer(timestamp.to_s, exception: false)
    return false if ts.nil?
    return false if (now.to_i - ts).abs > MAX_CLOCK_SKEW

    ActiveSupport::SecurityUtils.secure_compare(sign(timestamp, body, secret:), signature)
  end

  # Headers for an outgoing signed request (the pipeline trigger).
  def signed_headers(body, secret: self.secret)
    timestamp = Time.current.to_i.to_s
    {
      "Content-Type" => "application/json",
      TIMESTAMP_HEADER => timestamp,
      SIGNATURE_HEADER => sign(timestamp, body, secret:)
    }
  end

  # Verify an incoming request (the pipeline's callback).
  def verify_request(request)
    verify(request.headers[TIMESTAMP_HEADER], request.raw_post, request.headers[SIGNATURE_HEADER])
  end
end
