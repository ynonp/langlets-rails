# frozen_string_literal: true

# The project token is optional outside production, where developers and CI do
# not need a PostHog project to boot the application.
posthog_key = ENV["POSTHOG_API_KEY"].presence || Rails.application.credentials.dig(:posthog, :api_key)
raise "PostHog project API key is missing" if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank? && posthog_key.blank?

PostHog::Rails.configure do |config|
  config.auto_capture_exceptions = false
  config.use_tracing_headers = false
end

PostHog.init do |config|
  config.api_key = posthog_key
  config.host = ENV.fetch("POSTHOG_HOST", "https://us.i.posthog.com")
  config.test_mode = !Rails.env.production?
  # posthog-rails adds request metadata to every event. Keep only the explicit,
  # reviewed properties supplied by our controllers.
  config.before_send = proc do |event|
    %w[$current_url $request_path $request_method $user_agent $raw_user_agent $ip].each do |key|
      event[:properties]&.delete(key)
    end
    event
  end
end
