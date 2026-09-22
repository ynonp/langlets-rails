# frozen_string_literal: true

# The project token is optional. The SDK disables itself when the token is
# absent, so analytics can never prevent application startup.
posthog_key = ENV["POSTHOG_API_KEY"].presence || Rails.application.credentials.dig(:posthog, :api_key)
posthog_secret_key = ENV["POSTHOG_SECRET_KEY"].presence || Rails.application.credentials.dig(:posthog, :secret_key)

PostHog::Rails.configure do |config|
  config.auto_capture_exceptions = false
  config.use_tracing_headers = false
end

PostHog.init do |config|
  config.api_key = posthog_key
  config.secret_key = posthog_secret_key
  config.host = ENV.fetch("POSTHOG_HOST", "https://us.i.posthog.com")
  config.test_mode = !Rails.env.production?
  # posthog-rails adds request metadata to every event. Keep the query-free URL
  # explicitly supplied for page views and remove the remaining implicit data.
  config.before_send = proc do |event|
    %w[$request_path $request_method $user_agent $raw_user_agent $ip].each do |key|
      event[:properties]&.delete(key)
    end
    event[:properties]&.delete("$current_url") unless event[:event] == "$pageview"
    event
  end
end
