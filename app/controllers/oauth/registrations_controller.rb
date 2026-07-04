module Oauth
  # OAuth 2.0 Dynamic Client Registration (RFC 7591). Unauthenticated by
  # design: MCP clients self-register before any user has logged in.
  #
  # Abuse controls: per-IP rate limiting (config/initializers/rack_attack.rb)
  # and periodic deletion of registrations that never obtained a token
  # (CleanupStaleOauthRegistrationsJob, scheduled in initializers/good_job.rb).
  class RegistrationsController < ActionController::API
    def create
      redirect_uris = Array(params[:redirect_uris]).map(&:to_s)
      return rfc_error("invalid_redirect_uri", "redirect_uris is required") if redirect_uris.empty?
      unless redirect_uris.all? { |uri| valid_agent_redirect_uri?(uri) }
        return rfc_error("invalid_redirect_uri", "redirect URIs must be https or loopback http")
      end

      application = Doorkeeper::Application.new(
        name: params[:client_name].presence || "Unnamed agent client",
        redirect_uri: redirect_uris.join("\n"),
        scopes: allowed_scopes(params[:scope]),
        confidential: params[:token_endpoint_auth_method] != "none",
        dynamically_registered: true
      )

      unless application.save
        return rfc_error("invalid_client_metadata", application.errors.full_messages.join("; "))
      end

      render status: :created, json: registration_response(application, redirect_uris)
    end

    private

    def registration_response(application, redirect_uris)
      response = {
        client_id: application.uid,
        client_id_issued_at: application.created_at.to_i,
        client_name: application.name,
        redirect_uris: redirect_uris,
        grant_types: %w[authorization_code refresh_token],
        response_types: %w[code],
        token_endpoint_auth_method: application.confidential? ? "client_secret_basic" : "none",
        scope: application.scopes.to_s
      }
      if application.confidential?
        response[:client_secret] = application.plaintext_secret
        response[:client_secret_expires_at] = 0
      end
      response
    end

    def valid_agent_redirect_uri?(uri)
      parsed = URI.parse(uri)
      parsed.scheme == "https" ||
        (parsed.scheme == "http" && %w[127.0.0.1 localhost ::1 [::1]].include?(parsed.host))
    rescue URI::InvalidURIError
      false
    end

    # Narrow requested scopes to the configured ones; grant the defaults when
    # nothing valid was requested.
    def allowed_scopes(requested)
      configured = Doorkeeper.configuration.scopes.to_a
      wanted = requested.to_s.split & configured
      wanted.presence&.join(" ") || Doorkeeper.configuration.default_scopes.to_s
    end

    def rfc_error(code, description)
      render status: :bad_request, json: { error: code, error_description: description }
    end
  end
end
