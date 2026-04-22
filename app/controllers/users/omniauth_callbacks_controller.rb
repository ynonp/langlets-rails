# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Devise::Controllers::Rememberable

  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      remember_me(@user)
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_user_registration_url
    end
  end

  def github
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      remember_me(@user)
      set_flash_message(:notice, :success, kind: "GitHub") if is_navigational_format?
    else
      Rails.logger.info request.env["omniauth.auth"]
      Rails.logger.warn "User not persisted: #{@user.errors.full_messages.join(', ')}"
      session["devise.github_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_user_registration_url
    end
  end

  def failure
    if native_app?
      redirect_to "langlets://auth-failure"
    else
      redirect_to root_path
    end
  end

  private

  def after_sign_in_path_for(resource)
    if native_app?
      "langlets://auth-success"
    else
      super
    end
  end

  def native_app?
    request.user_agent&.include?("LangletsNative") ||
      request.env["omniauth.params"]&.dig("native_app").present?
  end
end
