module App
  # Where the iOS app hands over its APNs token, via the bridge--push component.
  #
  # Session-authenticated rather than a bearer: the app is a web view shell, so a
  # page always loads and the session is always there. (The share extension is the
  # thing that genuinely can't use the session — it's a separate process — but it
  # doesn't receive push tokens.)
  class DeviceTokensController < BaseController
    def create
      return head :unprocessable_entity if params[:token].blank?

      DeviceToken.register!(
        user: current_user,
        token: params[:token],
        environment: environment,
        app_version: params[:app_version]
      )

      head :ok
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Device token registration failed: #{e.message}"
      head :unprocessable_entity
    end

    # Turning notifications off is installation-scoped: remove only the token
    # handed over by this device, and only when it belongs to the signed-in user.
    def destroy
      return head :unprocessable_entity if params[:token].blank?

      current_user.device_tokens.where(token: params[:token]).delete_all
      head :no_content
    end

    private

    # A debug build and an App Store build on the same phone get different tokens,
    # valid against different APNs hosts, so the client tells us which it is.
    def environment
      candidate = params[:environment].to_s
      DeviceToken::ENVIRONMENTS.include?(candidate) ? candidate : "production"
    end
  end
end
