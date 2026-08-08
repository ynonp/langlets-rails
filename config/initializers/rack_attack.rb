# frozen_string_literal: true

# Throttling for the unauthenticated OAuth surface. Counters live in a
# per-process memory store rather than Rails.cache (solid_cache in production
# is DB-backed, which would turn every throttled request into extra DB
# writes). With multiple Puma workers the effective limit is
# limit * worker_count — good enough for abuse control here.
#
# In test the default null cache store stays in place, so counters never
# accumulate and throttles only fire in tests that install a real store.
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new unless Rails.env.test?

# Dynamic client registration (RFC 7591) is unauthenticated by design, so cap
# how fast a single IP can create OAuth applications. Legitimate clients
# register once and reuse their client_id.
Rack::Attack.throttle("oauth/register", limit: 5, period: 1.hour) do |req|
  req.ip if req.post? && req.path == "/oauth/register"
end

# Redeeming a native sign-in handoff is unauthenticated by construction — the
# token in the query string is the whole credential — and every call costs a
# lookup. The token is 256 random bits and single-use, so this is not what stands
# between an attacker and an account; it is what keeps a stranger from spending
# the endpoint. One device signs in once and redeems once, so the ceiling is far
# above any real use even on a shared IP.
Rack::Attack.throttle("users/native_handoff", limit: 30, period: 5.minutes) do |req|
  req.ip if req.get? && req.path == "/users/auth/native_handoff"
end

Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env["rack.attack.match_data"]
  retry_after = match_data ? match_data[:period] : 3600
  [
    429,
    { "content-type" => "application/json", "retry-after" => retry_after.to_s },
    [ { error: "rate_limited", error_description: "Too many requests, retry later" }.to_json ]
  ]
end
