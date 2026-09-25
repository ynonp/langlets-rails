module Api::V1::Native
  class SessionsController < BaseController
    def destroy
      doorkeeper_token.revoke
      extension = Doorkeeper::Application.find_by(uid: App::NativeTokensController::CLIENT_UID)
      user.oauth_access_tokens.where(application: extension).update_all(revoked_at: Time.zone.now) if extension
      user.device_tokens.where(token: params[:device_token]).destroy_all if params[:device_token].present?
      head :no_content
    end
  end
end
