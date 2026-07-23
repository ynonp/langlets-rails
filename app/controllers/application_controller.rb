class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # ?lang=all means "show content in every language": it clears the stored
  # language rather than selecting one. Web only — the native app always has a
  # language, picked during onboarding.
  ALL_LANGUAGES = "all".freeze

  before_action :set_translation_language
  before_action :store_language_in_session
  before_action :require_authentication_for_native_app
  before_action :require_language_for_native_app

  protected

  helper_method :current_translation_language
  def current_translation_language
    Current.translation_language
  end

  def set_translation_language
    code = request.subdomains.first.presence || "en"
    Current.translation_language = Language.find_by(iso_name: code) ||
      Language.find_by(english_name: "English") || Language.first

    locale = Current.translation_language&.iso_name&.to_sym
    I18n.locale = I18n.available_locales.include?(locale) ? locale : :en
  end

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
      persist_ios_language(params[:lang])
    end
  end

  # The language the user is learning, or nil when they asked to see content in
  # every language.
  helper_method :current_language_code
  def current_language_code
    code = params[:lang].presence || session[:lang] || restored_ios_language
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
    return if controller_name == "onboarding" && action_name.in?([ "welcome", "language" ])
    return if controller_name == "health"
    return if request.path.in?(["/home/privacy", "/home/terms", "/up"])

    redirect_to onboarding_welcome_path(returnto: request.fullpath)
  end

  # Carries the selected language onto every generated URL, so all content stays
  # in that language. Dropped once the user asks to see all content.
  def default_url_options
    super.merge(lang: current_language_code).compact
  end

  # Redirect to returnto param after successful sign in
  def after_sign_in_path_for(resource)
    path = pending_video_path || if params[:returnto].present?
      params[:returnto]
    elsif request.env['omniauth.origin']
      request.env['omniauth.origin']
    else
      root_path
    end

    native_app? ? native_sign_in_path(path, resource) : path
  end

  # Redirect to returnto param after successful sign up
  def after_sign_up_path_for(resource)
    pending_video_path || if params[:returnto].present?
      params[:returnto]
    else
      root_path
    end
  end

  # Redirect after sign out — both the sign-out button (sessions#destroy) and
  # account deletion (registrations#destroy) land here. signed_out=1 makes the
  # rendered page fire the bridge--sign-out component, so the native app wipes
  # its cookie store and stored language only after the server-side sign-out
  # completed (see layouts/application).
  def after_sign_out_path_for(resource_or_scope)
    # Native: every app screen requires a session, so any returnto would
    # bounce to sign-in anyway — and that redirect would drop the signed_out
    # marker before a page renders. Go to sign-in directly. lang is dropped
    # explicitly: it belonged to the account that just signed out, and
    # carrying it forward lets the next account skip onboarding.
    if native_app?
      # `lang` is cached independently from Devise's authentication keys.
      # Do not let an account switch inherit it even if the browser session
      # itself survives the sign-out/account-deletion redirect.
      session.delete(:lang)
      return new_user_session_path(signed_out: 1, lang: nil)
    end

    path = params[:returnto].presence || root_path
    separator = path.include?("?") ? "&" : "?"
    "#{path}#{separator}signed_out=1"
  end

  private

  def pending_video_path
    video_url = cookies.encrypted[GuestImportRequestsController::PENDING_VIDEO_COOKIE]
    return if video_url.blank?

    cookies.delete(GuestImportRequestsController::PENDING_VIDEO_COOKIE)
    new_app_import_request_path(url: video_url)
  end

  def persist_ios_language(code)
    return unless native_app? && user_signed_in?
    return unless Language.exists?(iso_name: code)
    return if current_user.ios_lang == code

    current_user.update!(ios_lang: code)
  end

  def restored_ios_language
    return unless native_app? && user_signed_in?

    code = current_user.ios_lang
    return unless code.present? && Language.exists?(iso_name: code)

    session[:lang] = code
  end

  def native_sign_in_path(path, user)
    code = user.ios_lang
    return path unless code.present? && Language.exists?(iso_name: code)

    session[:lang] = code
    uri = URI.parse(path)
    query = Rack::Utils.parse_nested_query(uri.query)
    query["lang"] = code
    query["ios_lang"] = code
    uri.query = Rack::Utils.build_nested_query(query)
    uri.to_s
  end
end
