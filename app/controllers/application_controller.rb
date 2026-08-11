class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # ?lang=all means "show content in every language": it selects nothing rather
  # than one language, so default_url_options stops propagating the param. Web
  # only — the native app always has a language, picked during onboarding.
  ALL_LANGUAGES = "all".freeze

  before_action :set_translation_language
  before_action :persist_native_language
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

  # Drives the dot on the profile menu, on every authenticated page. Memoized
  # per request because both the header and the menu ask.
  helper_method :unread_notifications_count
  def unread_notifications_count
    return 0 if current_user.nil?

    @unread_notifications_count ||= current_user.notifications.unread.count
  end

  # Returns true if the request comes from one of the Hotwire Native apps.
  # Used to customize behavior (e.g., OAuth redirects) for the native shells.
  #
  # Deliberately platform-blind: iOS and Android send the same "LangletsNative"
  # marker because they route to the same /app content, and there is no
  # version- or platform-specific native routing on the server. Reach for
  # android_app? only where the platforms genuinely differ.
  helper_method :native_app?
  def native_app?
    request.user_agent&.include?("LangletsNative")
  end

  # Returns true only for the Hotwire Native Android app.
  #
  # This is for content that is *false* on one platform rather than merely
  # styled differently — currently just Add Video's "share to Langlets from the
  # provider's share menu" hint, which describes the iOS share extension.
  # Android has no counterpart, so the sentence would send users looking for a
  # feature that isn't there.
  #
  # Presentation differences do not belong here: both shells render the same
  # native views, and a rule keyed on the platform is a rule the other platform
  # silently stops getting.
  helper_method :android_app?
  def android_app?
    native_app? && request.user_agent&.include?("(Android)")
  end

  # Whether this client can see the Pro screen.
  #
  # Pro is no longer sold anywhere — it is granted by hand from the console
  # (see User#pro!) after someone reaches out on Discord, and the screen just
  # explains that and links out. There is nothing left to transact, so both
  # native shells can show it; a browser still can't, because every Pro CTA in
  # the app routes through App::ProController and the web equivalents already
  # carry their own explanation (app.import_requests.new.out_of_credits_web_hint)
  # instead of linking here.
  helper_method :can_view_pro_screen?
  def can_view_pro_screen?
    native_app?
  end

  # Returns true for mobile browsers (including tablets).
  def mobile?
    request.user_agent&.match?(/Mobi|Android|iPhone|iPad|iPod|Windows Phone|webOS|BlackBerry|Opera Mini/i)
  end

  # Native picks its language during onboarding and must keep it across app
  # launches, so the selection lands in the user's stored preferences. Web keeps
  # it in the URL instead, where it stays visible and can be removed.
  def persist_native_language
    return if params[:lang].blank? || params[:lang] == ALL_LANGUAGES

    persist_ios_language(params[:lang])
  end

  # The language the user is learning, or nil when they asked to see content in
  # every language. Web reads the URL alone — default_url_options carries the
  # param across links, so dropping it from the address bar clears the filter.
  helper_method :current_language_code
  def current_language_code
    code = params[:lang].presence || native_language_code
    code unless code == ALL_LANGUAGES
  end

  def require_authentication_for_native_app
    return unless native_app?
    return if user_signed_in?
    return if devise_controller?
    return if controller_name == "courses" && action_name == "index"
    return if controller_name == "onboarding" && action_name.in?([ "welcome", "video", "language" ])
    return if controller_name == "try" && action_name == "show"
    return if controller_name == "health"
    return if request.path.in?(["/home/privacy", "/home/terms", "/up"])

    redirect_to new_user_session_path(returnto: request.fullpath)
  end

  def require_language_for_native_app
    return unless native_app?
    return unless user_signed_in?
    return if current_language_code.present?
    return if pending_guest_claim?
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
    path = pending_import_path || if params[:returnto].present?
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
    pending_import_path || if params[:returnto].present?
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
    # explicitly so the next account can't inherit it and skip onboarding; it
    # now lives on the user record, so signing out drops it on its own.
    return new_user_session_path(signed_out: 1, lang: nil) if native_app?

    path = params[:returnto].presence || root_path
    separator = path.include?("?") ? "&" : "?"
    "#{path}#{separator}signed_out=1"
  end

  private

  # A guest who approved a /try preview gets their admin-started import attached
  # after the first successful authentication — once. The legacy raw-URL marker
  # remains readable for cookies issued by older deployments.
  def pending_import_path
    cookie_evaluation = pending_evaluation_signup
    if cookie_evaluation&.user.present? && cookie_evaluation.user != current_user
      cookies.delete(GuestImportRequestsController::EVALUATION_SIGNUP_COOKIE)
      cookie_evaluation = nil
    end
    evaluation_signup = if cookie_evaluation && (cookie_evaluation.user.nil? || cookie_evaluation.user == current_user)
      cookie_evaluation
    else
      account_evaluation = current_user.evaluation_signup
      account_evaluation if account_evaluation && EvaluationSignup.available.exists?(id: account_evaluation.id)
    end

    if evaluation_signup
      claim = evaluation_signup.claim!(current_user)
      evaluation_signup.update!(course: claim.course) if claim.course && evaluation_signup.course_id != claim.course_id
      evaluation_signup.consume!
      cookies.delete(GuestImportRequestsController::EVALUATION_SIGNUP_COOKIE)

      if native_app? && current_user.ios_lang.blank? && claim.clip_language.present?
        detected_language = Language.find_by(english_name: claim.clip_language)
        current_user.update!(ios_lang: detected_language.iso_name) if detected_language
      end

      return course_path(evaluation_signup.course)
    end

    video_url = cookies.encrypted[GuestImportRequestsController::PENDING_VIDEO_COOKIE]
    if video_url.present?
      cookies.delete(GuestImportRequestsController::PENDING_VIDEO_COOKIE)
      return new_app_import_request_path(url: video_url)
    end

    nil
  end

  def persist_ios_language(code)
    return unless native_app? && user_signed_in?
    return unless Language.exists?(iso_name: code)
    return if current_user.ios_lang == code

    current_user.update!(ios_lang: code)
  end

  def pending_evaluation_signup
    token = cookies.encrypted[GuestImportRequestsController::EVALUATION_SIGNUP_COOKIE]
    EvaluationSignup.available.find_by(token: token) if token.present?
  end

  def link_pending_evaluation_signup(user)
    evaluation_signup = pending_evaluation_signup
    return unless evaluation_signup
    if evaluation_signup.user.present? && evaluation_signup.user != user
      cookies.delete(GuestImportRequestsController::EVALUATION_SIGNUP_COOKIE)
      return
    end

    evaluation_signup.claim!(user)
    cookies.delete(GuestImportRequestsController::EVALUATION_SIGNUP_COOKIE)
  end

  def pending_guest_claim?
    return false unless native_app? && current_user

    current_user.import_requests.detecting.where(
      create_song_progress_id: ImportRequest.where(guest_started: true).select(:create_song_progress_id)
    ).exists?
  end

  def native_language_code
    return unless native_app? && user_signed_in?

    code = current_user.ios_lang
    code if code.present? && Language.exists?(iso_name: code)
  end

  def native_sign_in_path(path, user)
    code = user.ios_lang
    return path unless code.present? && Language.exists?(iso_name: code)

    uri = URI.parse(path)
    query = Rack::Utils.parse_nested_query(uri.query)
    query["lang"] = code
    query["ios_lang"] = code
    uri.query = Rack::Utils.build_nested_query(query)
    uri.to_s
  end
end
