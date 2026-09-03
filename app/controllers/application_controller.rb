class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  before_action :set_translation_language
  before_action :require_authentication_for_native_app

  protected

  helper_method :current_translation_language
  def current_translation_language
    Current.translation_language
  end

  def set_translation_language
    Current.translation_language = if native_app? && current_user
      current_user.native_language
    else
      code = request.subdomains.first.presence || "en"
      Language.find_by(iso_name: code) ||
        Language.find_by(english_name: "English") || Language.first
    end

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
  # Keep this for behavior that is genuinely platform-specific rather than for
  # presentation differences. Both shells render the same native views, and
  # both support importing from a provider's share menu (through different
  # native implementations).
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

  def require_authentication_for_native_app
    return unless native_app?
    return if user_signed_in?
    return if devise_controller?
    return if controller_name == "courses" && action_name == "index"
    return if controller_name == "onboarding" && action_name.in?([ "welcome", "video", "language" ])
    return if controller_name == "try" && action_name == "show"
    return if controller_name == "health"
    return if request.path.in?([ "/home/privacy", "/home/terms", "/up" ])

    redirect_to new_user_session_path(returnto: request.fullpath)
  end

  # Redirect to returnto param after successful sign in
  def after_sign_in_path_for(resource)
    pending = pending_import_path
    return pending if pending
    return params[:returnto] if params[:returnto].present?
    return request.env["omniauth.origin"] if request.env["omniauth.origin"]

    root_path
  end

  # Redirect to returnto param after successful sign up
  def after_sign_up_path_for(resource)
    pending_import_path || params[:returnto].presence || root_path
  end

  # Redirect after sign out — both the sign-out button (sessions#destroy) and
  # account deletion (registrations#destroy) land here. signed_out=1 makes the
  # rendered page fire the bridge--sign-out component, so the native app wipes
  # its cookie store only after the server-side sign-out
  # completed (see layouts/application).
  def after_sign_out_path_for(resource_or_scope)
    # Native: every app screen requires a session, so any returnto would
    # bounce to sign-in anyway — and that redirect would drop the signed_out
    # marker before a page renders. Go to sign-in directly.
    return new_user_session_path(signed_out: 1) if native_app?

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

      return course_path(evaluation_signup.course)
    end

    video_url = cookies.encrypted[GuestImportRequestsController::PENDING_VIDEO_COOKIE]
    if video_url.present?
      cookies.delete(GuestImportRequestsController::PENDING_VIDEO_COOKIE)
      return new_app_import_request_path(url: video_url)
    end

    nil
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
end
