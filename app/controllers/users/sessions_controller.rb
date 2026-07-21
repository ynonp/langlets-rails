# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController  
  # before_action :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  def new
    super
  end

  # POST /resource/sign_in
  def create
    params[resource_name][:remember_me] = '1' if params[resource_name]
    super
  end

  # DELETE /resource/sign_out
  def destroy
    if native_app? && current_user
      current_user.oauth_access_tokens
                  .joins(:application)
                  .where(oauth_applications: { uid: App::NativeTokensController::CLIENT_UID }, revoked_at: nil,
                         scopes: App::NativeTokensController::SCOPES)
                  .find_each(&:revoke)
    end
    super
  end

  protected

  def after_sign_in_path_for(resource)
    super
  end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
