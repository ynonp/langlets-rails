module Api
  module V1
    # Bearer-token API for AI agents and the langlets CLI. Tokens are issued by
    # Doorkeeper (see /oauth/authorize, /oauth/register).
    class BaseController < ActionController::API
      before_action :touch_token_last_used

      rescue_from PaginatedQuery::UnknownLanguageError do |error|
        render status: :unprocessable_entity,
               json: { error: "unknown_language", error_description: error.message }
      end

      private

      def current_resource_owner
        @current_resource_owner ||= User.find(doorkeeper_token.resource_owner_id)
      end

      def touch_token_last_used
        return unless doorkeeper_token&.accessible?
        return if doorkeeper_token.last_used_at.present? && doorkeeper_token.last_used_at > 1.minute.ago

        doorkeeper_token.update_column(:last_used_at, Time.current)
      end

      # 401s advertise the RFC 9728 resource metadata so agents can discover
      # the OAuth server and self-onboard.
      def doorkeeper_unauthorized_render_options(error: nil)
        headers["WWW-Authenticate"] =
          %(Bearer realm="langlets", resource_metadata="#{request.base_url}/.well-known/oauth-protected-resource")
        { json: { error: "unauthorized", error_description: error&.description } }
      end

      def doorkeeper_forbidden_render_options(error: nil)
        { json: { error: "insufficient_scope", error_description: error&.description } }
      end
    end
  end
end
