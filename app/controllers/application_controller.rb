class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # ?lang=all means "show content in every language": it clears the stored
  # language rather than selecting one. Web only — the native app always has a
  # language, picked during onboarding.
  ALL_LANGUAGES = "all".freeze

  before_action :store_language_in_session
  before_action :require_authentication_for_native_app
  before_action :require_language_for_native_app

  protected

  # The active color theme for this request. Logged-in users read it from their
  # stored preferences; everyone falls back to a cookie, then the default theme.
  helper_method :current_theme
  def current_theme
    candidate = current_user&.theme || cookies[:theme]
    User::VALID_THEMES.include?(candidate) ? candidate : User::DEFAULT_THEME
  end

  # Returns true if the request comes from the Hotwire Native iOS app.
  # Used to customize behavior (e.g., OAuth redirects) for the native app.
  helper_method :native_app?
  def native_app?
    request.user_agent&.include?("LangletsNative")
  end

  # Returns true for mobile browsers (including tablets).
  def mobile?
    request.user_agent&.match?(/Mobi|Android|iPhone|iPad|iPod|Windows Phone|webOS|BlackBerry|Opera Mini/i)
  end

  def store_language_in_session
    return if params[:lang].blank?

    if params[:lang] == ALL_LANGUAGES
      session.delete(:lang)
    else
      session[:lang] = params[:lang]
    end
  end

  # The language the user is learning, or nil when they asked to see content in
  # every language.
  helper_method :current_language_code
  def current_language_code
    code = params[:lang].presence || session[:lang]
    code unless code == ALL_LANGUAGES
  end

  def require_authentication_for_native_app
    return unless native_app?
    return if user_signed_in?
    return if devise_controller?
    return if controller_name == "onboarding" && action_name == "language"
    return if controller_name == "health"
    return if request.path.in?(["/home/privacy", "/home/terms", "/up"])

    redirect_to new_user_session_path(returnto: request.fullpath)
  end

  def require_language_for_native_app
    return unless native_app?
    return unless user_signed_in?
    return if current_language_code.present?
    return if devise_controller?
    return if controller_name == "onboarding" && action_name == "language"
    return if controller_name == "health"
    return if request.path.in?(["/home/privacy", "/home/terms", "/up"])

    redirect_to onboarding_language_path(returnto: request.fullpath)
  end

  # Carries the selected language onto every generated URL, so all content stays
  # in that language. Dropped once the user asks to see all content.
  def default_url_options
    super.merge(lang: current_language_code).compact
  end

  # Redirect to returnto param after successful sign in
  def after_sign_in_path_for(resource)
    if params[:returnto].present?
      params[:returnto]
    elsif request.env['omniauth.origin']
      request.env['omniauth.origin']
    else
      root_path
    end
  end

  # Redirect to returnto param after successful sign up
  def after_sign_up_path_for(resource)
    if params[:returnto].present?
      params[:returnto]
    else
      root_path
    end
  end

  # Redirect to returnto param after successful sign out
  def after_sign_out_path_for(resource_or_scope)
    if params[:returnto].present?
      params[:returnto]
    else
      root_path
    end
  end
end
