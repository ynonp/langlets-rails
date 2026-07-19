require "test_helper"

class PipelineHmacTest < ActiveSupport::TestCase
  SECRET = "test-hmac-secret"

  test "sign/verify roundtrip" do
    timestamp = Time.current.to_i.to_s
    signature = PipelineHmac.sign(timestamp, '{"a":1}', secret: SECRET)

    assert PipelineHmac.verify(timestamp, '{"a":1}', signature, secret: SECRET)
  end

  test "verify rejects a tampered body" do
    timestamp = Time.current.to_i.to_s
    signature = PipelineHmac.sign(timestamp, '{"a":1}', secret: SECRET)

    assert_not PipelineHmac.verify(timestamp, '{"a":2}', signature, secret: SECRET)
  end

  test "verify rejects the wrong secret" do
    timestamp = Time.current.to_i.to_s
    signature = PipelineHmac.sign(timestamp, "body", secret: "other")

    assert_not PipelineHmac.verify(timestamp, "body", signature, secret: SECRET)
  end

  test "verify rejects a stale timestamp" do
    stale = 1.hour.ago.to_i.to_s
    signature = PipelineHmac.sign(stale, "body", secret: SECRET)

    assert_not PipelineHmac.verify(stale, "body", signature, secret: SECRET)
    # The same request inside the window is fine.
    assert PipelineHmac.verify(stale, "body", signature, secret: SECRET, now: 59.minutes.ago)
  end

  test "verify rejects a non-numeric timestamp and blank inputs" do
    signature = PipelineHmac.sign("123", "body", secret: SECRET)

    assert_not PipelineHmac.verify("not-a-number", "body", signature, secret: SECRET)
    assert_not PipelineHmac.verify("123", "body", nil, secret: SECRET)
    assert_not PipelineHmac.verify("123", "body", signature, secret: nil)
  end

  test "signed_headers produce a signature the Deno side's scheme accepts" do
    body = { ops: [] }.to_json
    headers = PipelineHmac.signed_headers(body, secret: SECRET)

    timestamp = headers[PipelineHmac::TIMESTAMP_HEADER]
    expected = OpenSSL::HMAC.hexdigest("SHA256", SECRET, "#{timestamp}.#{body}")
    assert_equal expected, headers[PipelineHmac::SIGNATURE_HEADER]
  end

  test "sign without a configured secret raises loudly" do
    assert_raises(ArgumentError) { PipelineHmac.sign("123", "body", secret: nil) }
  end
end
