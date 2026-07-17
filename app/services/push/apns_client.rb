require "apnotic"

module Push
  # NotConfigured lives in its own file so Zeitwerk can autoload it.

  # Sends APNs pushes.
  #
  # Token auth (.p8) rather than certificates: one key covers both sandbox and
  # production, and it never expires — no annual renewal to forget. Credentials
  # live under `apns:` (key_id, team_id, bundle_id, auth_key), deliberately
  # separate from the `apple_*` Sign in with Apple key so the two can be revoked
  # and rotated independently.
  #
  # Connections are pooled per environment and memoised for the life of the
  # process: an APNs connection is an HTTP/2 session and is meant to be long-lived.
  class ApnsClient
    Result = Data.define(:ok, :status, :reason) do
      def ok? = ok
      # Apple saying "this token is dead" — 410, or a 400 whose reason names the
      # token. Anything else is a transient failure and the device stays active.
      def token_dead? = status == 410 || %w[BadDeviceToken Unregistered].include?(reason)
    end

    POOL_SIZE = 5
    CONNECT_TIMEOUT = 5

    class << self
      def configured?
        credentials.present? &&
          credentials[:key_id].present? &&
          credentials[:team_id].present? &&
          credentials[:auth_key].present?
      end

      def bundle_id
        credentials&.dig(:bundle_id)
      end

      # Returns a Result. Raises NotConfigured only if the key is missing entirely
      # — a delivery failure is data, not an exception.
      def push(device_token, payload)
        raise NotConfigured, "apns credentials are not set" unless configured?

        notification = build_notification(device_token.token, payload)
        response = pool_for(device_token.environment).with { |conn| conn.push(notification) }

        # apnotic returns nil when the request itself timed out.
        return Result.new(ok: false, status: nil, reason: "timeout") if response.nil?

        Result.new(
          ok: response.ok?,
          status: response.status.to_i,
          reason: (response.body.is_a?(Hash) ? response.body["reason"] : nil)
        )
      end

      # Long-lived HTTP/2 sessions; don't build one per push.
      def pool_for(environment)
        @pools ||= {}
        @pools[environment] ||= build_pool(environment)
      end

      def reset!
        @pools&.each_value { |pool| pool.shutdown { |conn| conn.close } }
        @pools = nil
        @credentials = nil
      end

      private

      def credentials
        return @credentials if defined?(@credentials) && @credentials

        @credentials = Rails.application.credentials.apns
      end

      def build_pool(environment)
        url = environment.to_s == "sandbox" ? Apnotic::ConnectionPool::APPLE_DEVELOPMENT_SERVER_URL : nil

        options = {
          auth_method: :token,
          cert_path: StringIO.new(credentials[:auth_key].to_s),
          key_id: credentials[:key_id],
          team_id: credentials[:team_id],
          connect_timeout: CONNECT_TIMEOUT
        }
        options[:url] = url if url

        Apnotic::ConnectionPool.new(options, size: POOL_SIZE) do |connection|
          connection.on(:error) { |exception| Rails.logger.error("APNs connection error: #{exception}") }
        end
      end

      def build_notification(token, payload)
        notification = Apnotic::Notification.new(token)
        notification.topic = bundle_id
        notification.alert = payload[:alert]
        notification.sound = payload.fetch(:sound, "default")
        notification.badge = payload[:badge] if payload.key?(:badge)
        notification.custom_payload = payload[:custom_payload] if payload[:custom_payload].present?
        notification.push_type = "alert"
        notification
      end
    end
  end
end
