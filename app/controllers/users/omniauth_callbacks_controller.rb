# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Devise::Controllers::Rememberable

  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      unless user_signed_in? && current_user == @user
        sign_in(@user, event: :authentication)
        remember_me(@user)
      end
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
      redirect_to after_sign_in_path_for(@user), allow_other_host: native_app?
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_user_registration_url
    end
  end

  def github
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      unless user_signed_in? && current_user == @user
        sign_in(@user, event: :authentication)
        remember_me(@user)
      end
      set_flash_message(:notice, :success, kind: "GitHub") if is_navigational_format?
      redirect_to after_sign_in_path_for(@user), allow_other_host: native_app?
    else
      Rails.logger.info request.env["omniauth.auth"]
      Rails.logger.warn "User not persisted: #{@user.errors.full_messages.join(', ')}"
      session["devise.github_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_user_registration_url
    end
  end

  def failure
    if native_app?
      redirect_to "langlets://auth-failure", allow_other_host: true
    else
      redirect_to root_path
    end
  end

  def native_success
    if user_signed_in?
      redirect_to "langlets://auth-success", allow_other_host: true
    else
      redirect_to "langlets://auth-failure", allow_other_host: true
    end
  end

  private

  def after_sign_in_path_for(resource)
    if native_app?
      users_auth_native_success_path
    else
      super
    end
  end

  def native_app?
    request.user_agent&.include?("LangletsNative") ||
      request.env["omniauth.params"]&.dig("native_app").present?
  end
end
