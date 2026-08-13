# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Devise::Controllers::Rememberable

  # Apple delivers its callback as a cross-site form POST, which carries no
  # Rails CSRF token. OmniAuth dispatches callback errors to #failure using the
  # same request, so that action must be exempt as well or the OAuth error gets
  # replaced by an InvalidAuthenticityToken response.
  skip_before_action :verify_authenticity_token, only: [ :native_google, :native_apple, :apple, :failure ]

  # Providers whose flow the native app may open in the device browser. An
  # allowlist because the value is pasted straight into the redirect below, and
  # an open redirect on an unauthenticated endpoint is exactly the thing an
  # OAuth flow must not have. Google is absent deliberately: it refuses to
  # render its consent screen in any embedded or app-launched browser context we
  # can use here, which is what the native Google SDKs exist for.
  HANDOFF_PROVIDERS = %w[github apple].freeze

  # Marks a device-browser session as belonging to the native app, and carries
  # the app's PKCE-style challenge from the start of the flow to its end.
  HANDOFF_COOKIE = :native_auth_handoff

  # How long a started flow may take. Generous — it spans reading a consent
  # screen, and possibly a password manager and a 2FA prompt — because the
  # cookie is only a marker; the credential it leads to lives for
  # NativeAuthHandoff::TTL.
  HANDOFF_WINDOW = 30.minutes

  # What the handoff endpoint answers with. Nobody reads it: the caller is a
  # throwaway web view that exists to receive Set-Cookie and report that the
  # page loaded. A document rather than an empty body so that it definitely
  # commits and fires the callback the app is waiting on.
  HANDOFF_BODY = "<!DOCTYPE html><title>Langlets</title>".html_safe.freeze

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

  def apple
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      unless user_signed_in? && current_user == @user
        sign_in(@user, event: :authentication)
        remember_me(@user)
      end
      set_flash_message(:notice, :success, kind: "Apple") if is_navigational_format?
      redirect_to after_sign_in_path_for(@user), allow_other_host: native_app?
    else
      Rails.logger.warn "User not persisted: #{@user.errors.full_messages.join(', ')}"
      session["devise.apple_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_user_registration_url
    end
  end

  def failure
    if native_app?
      forget_handoff_challenge
      redirect_to "langlets://auth-failure", allow_other_host: true
    else
      redirect_to root_path
    end
  end

  def native_success
    # Read before the early return: whether this succeeded or failed, the
    # browser is done with the challenge and should not keep a cookie that
    # marks every later request in it as native.
    challenge = handoff_challenge
    forget_handoff_challenge

    unless user_signed_in?
      redirect_to "langlets://auth-failure", allow_other_host: true
      return
    end

    query = {}
    # Present only for the Android flow, which reached here in a Chrome Custom
    # Tab and therefore established its session in the wrong cookie jar. iOS
    # sets no challenge because it does not need one: ASWebAuthenticationSession
    # already shares its jar with the web view.
    query[:handoff] = NativeAuthHandoff.issue!(current_user, challenge) if challenge.present?

    url = "langlets://auth-success"
    url = "#{url}?#{query.to_query}" if query.any?

    redirect_to url, allow_other_host: true
  end

  # Opens an OAuth flow that will run start-to-finish in the device browser
  # rather than in the app's web view, and marks this browser as belonging to
  # the native app so the callback knows where to send the user afterwards.
  #
  # The redirect is the point. Sending the app straight to
  # `/users/auth/:provider` would work just as well for GitHub, but the marker
  # has to be set *before* the request phase for Apple: Apple answers with a
  # cross-site form POST, which a SameSite=Lax session cookie does not
  # accompany, so by the time the callback runs `omniauth.params` — where
  # `native_app=1` would have been kept — is gone. A separate cookie of our own
  # survives that, which is why the flow starts here instead.
  def native_handoff_start
    provider = params[:provider].to_s
    challenge = params[:challenge].to_s

    unless HANDOFF_PROVIDERS.include?(provider) && challenge.match?(NativeAuthHandoff::CHALLENGE_FORMAT)
      redirect_to new_user_session_path, alert: "Sign-in could not be started"
      return
    end

    remember_handoff_challenge(challenge)

    # `native_app=1` is redundant here for GitHub and unavailable for Apple, but
    # it costs nothing and keeps the request phase identical to the one iOS
    # opens, so a provider console only ever sees the one shape.
    redirect_to "/users/auth/#{provider}?native_app=1"
  end

  # Spends a handoff token, which is the moment the session finally exists in
  # the web view's cookie jar. Called by the app immediately after the
  # `langlets://auth-success` deep link, and by nothing else.
  #
  # Answers with a tiny page rather than a redirect: the caller is a throwaway
  # web view whose only job is to receive `Set-Cookie` — Android's CookieManager
  # is process-global, so cookies it stores are the tab web views' cookies —
  # and it should not spend a round trip rendering a real screen nobody sees.
  def native_handoff
    user = NativeAuthHandoff.redeem(params[:token], params[:verifier])

    if user.nil?
      render html: HANDOFF_BODY, layout: false, status: :unauthorized
      return
    end

    sign_in(user, event: :authentication)
    remember_me(user)

    render html: HANDOFF_BODY, layout: false
  end

  # Signs the user in from a Google credential obtained natively, by whichever of
  # the two shapes the platform's SDK produces:
  #
  # - `id_token` — a Google ID token (a JWT), what Android's Credential Manager
  #   returns. Verified here against Google's JWKS, exactly like `native_apple`
  #   verifies Apple's. Nothing is exchanged with Google: the signature, the
  #   audience and the expiry are the proof.
  #
  # - `code` — a serverAuthCode, what the iOS Google Sign-In SDK returns. Traded
  #   with Google for an access token, which is then spent on the userinfo
  #   endpoint.
  #
  # Both exist because the two platforms' supported SDKs disagree, not because
  # the app wants two flows. Android's route is the ID token because Credential
  # Manager is the API Google supports there, and because obtaining a
  # serverAuthCode on Android additionally requires registering an Android OAuth
  # client bound to the app's signing certificate — configuration this flow does
  # not otherwise need.
  #
  # Note neither shape involves a redirect_uri, which is the other reason Android
  # signs in this way: the browser-redirect flow cannot complete there at all.
  # It starts in the app's WebView, where Rails writes `omniauth.state` into the
  # session cookie, and Hotwire hands accounts.google.com to a Chrome Custom Tab
  # — a separate cookie jar, so the callback arrives without the state it is
  # checked against, and any session it did establish would belong to Chrome
  # rather than to the app.
  def native_google
    identity = if params[:id_token].present?
                 google_identity_from_id_token(params[:id_token])
    elsif params[:code].present?
                 google_identity_from_auth_code(params[:code], params[:redirect_uri].presence || "")
    else
                 redirect_to new_user_session_path, alert: "Missing Google credential"
                 return
    end

    if identity.nil?
      redirect_to new_user_session_path, alert: "Google authentication failed"
      return
    end

    # Build an OmniAuth-style auth hash and sign the user in
    info = AuthInfo.new(email: identity[:email], name: identity[:name])
    auth = AuthHash.new(provider: "google_oauth2", uid: identity[:uid], info: info)

    @user = User.from_omniauth(auth)

    if @user.persisted?
      sign_in(@user, event: :authentication)
      remember_me(@user)
      redirect_to root_path
    else
      session["devise.google_data"] = { info: { email: identity[:email] } }
      redirect_to new_user_registration_url
    end
  end

  # Accepts an Apple identity token (JWT) from the native iOS app
  # (AuthenticationServices / Sign in with Apple), verifies it against
  # Apple's public keys and signs the user in.
  def native_apple
    identity_token = params[:identity_token]

    if identity_token.blank?
      redirect_to new_user_session_path, alert: "Missing identity token"
      return
    end

    claims = decode_apple_identity_token(identity_token)

    if claims.nil? || claims[:email].blank?
      redirect_to new_user_session_path, alert: "Apple authentication failed"
      return
    end

    info = AuthInfo.new(email: claims[:email], name: params[:name].presence)
    auth = AuthHash.new(provider: "apple", uid: claims[:sub], info: info)

    @user = User.from_omniauth(auth)

    if @user.persisted?
      sign_in(@user, event: :authentication)
      remember_me(@user)
      redirect_to root_path
    else
      session["devise.apple_data"] = { info: { email: claims[:email] } }
      redirect_to new_user_registration_url
    end
  end

  private

  APPLE_ISSUER = "https://appleid.apple.com"
  # Audiences allowed for native identity tokens: the iOS app's bundle id.
  APPLE_NATIVE_CLIENT_IDS = [ "com.ynonp.langlets" ].freeze

  # Verifies signature (against Apple's JWKS), issuer, audience and expiry.
  # Returns the token claims, or nil when the token is invalid.
  def decode_apple_identity_token(token)
    id_token = JSON::JWT.decode(token, :skip_verification)
    jwk = JSON::JWK::Set::Fetcher.fetch("#{APPLE_ISSUER}/auth/keys", kid: id_token.kid)
    id_token.verify!(jwk)

    return nil unless id_token[:iss] == APPLE_ISSUER
    return nil unless APPLE_NATIVE_CLIENT_IDS.include?(id_token[:aud])
    return nil unless id_token[:exp].to_i >= Time.now.to_i

    id_token
  rescue StandardError => e
    Rails.logger.error "Apple identity token verification failed: #{e.message}"
    nil
  end

  # Google signs its ID tokens with the keys published here, and stamps them with
  # one of these two issuer spellings — both are current, and Google's own
  # libraries accept either, so checking for one alone rejects valid tokens.
  GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs".freeze
  GOOGLE_ISSUERS = [ "https://accounts.google.com", "accounts.google.com" ].freeze

  # Verifies a Google ID token and returns { uid:, email:, name: }, or nil.
  #
  # The audience check is the load-bearing one. A Google ID token is not a
  # capability, it is an assertion about a user made *to a particular client*,
  # and any app can obtain a validly-signed token for its own client id. Without
  # pinning `aud` to our client id, a token minted for someone else's app would
  # verify here and sign that person in.
  #
  # `email_verified` matters for the same reason accounts are keyed on email:
  # User.from_omniauth matches on it, so an unverified address would let someone
  # claim an existing account by asserting its address at their identity
  # provider.
  def google_identity_from_id_token(token)
    id_token = JSON::JWT.decode(token, :skip_verification)
    jwk = JSON::JWK::Set::Fetcher.fetch(GOOGLE_JWKS_URL, kid: id_token.kid)
    id_token.verify!(jwk)

    return nil unless GOOGLE_ISSUERS.include?(id_token[:iss])
    return nil unless id_token[:aud] == Rails.application.credentials.google_client_id
    return nil unless id_token[:exp].to_i >= Time.now.to_i
    # The claim arrives as a real boolean from Google and as the string "true"
    # from some intermediaries; treat anything else as unverified.
    return nil unless [ true, "true" ].include?(id_token[:email_verified])
    return nil if id_token[:email].blank?

    { uid: id_token[:sub], email: id_token[:email], name: id_token[:name] }
  rescue StandardError => e
    Rails.logger.error "Google identity token verification failed: #{e.message}"
    nil
  end

  # Trades an iOS serverAuthCode for an access token and spends it on the
  # userinfo endpoint. Returns { uid:, email:, name: }, or nil.
  def google_identity_from_auth_code(code, redirect_uri)
    token_response = exchange_google_code(code, redirect_uri)

    if token_response["access_token"].blank?
      Rails.logger.error "Google token exchange failed: #{token_response.inspect}"
      return nil
    end

    user_info = fetch_google_user_info(token_response["access_token"])

    if user_info["email"].blank?
      Rails.logger.error "Google user info missing email: #{user_info.inspect}"
      return nil
    end

    { uid: user_info["id"], email: user_info["email"], name: user_info["name"] }
  end

  def exchange_google_code(code, redirect_uri)
    uri = URI("https://oauth2.googleapis.com/token")
    response = Net::HTTP.post_form(uri, {
      "code" => code,
      "client_id" => Rails.application.credentials.google_client_id,
      "client_secret" => Rails.application.credentials.google_client_secret,
      "redirect_uri" => redirect_uri,
      "grant_type" => "authorization_code"
    })
    JSON.parse(response.body)
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "Google token exchange error: #{e.message}"
    {}
  end

  def fetch_google_user_info(access_token)
    uri = URI("https://www.googleapis.com/oauth2/v2/userinfo")
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{access_token}"
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
    JSON.parse(response.body)
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "Google user info error: #{e.message}"
    {}
  end

  def after_sign_in_path_for(resource)
    if native_app?
      users_auth_native_success_path
    else
      super
    end
  end

  # Whether this request belongs to one of the native shells.
  #
  # Three spellings because the three flows leave three different traces. The
  # user agent covers anything running in the app's own web view. `omniauth
  # .params` covers a browser flow whose session survived to the callback — iOS
  # via ASWebAuthenticationSession, and GitHub on Android. The handoff cookie
  # covers the one case neither reaches: Apple's cross-site POST callback, which
  # arrives in the device browser with no session and no `omniauth.params` at
  # all. Without it that callback would look like an ordinary web sign-in and
  # strand the user on a marketing page inside a Custom Tab.
  def native_app?
    request.user_agent&.include?("LangletsNative") ||
      request.env["omniauth.params"]&.dig("native_app").present? ||
      handoff_challenge.present?
  end

  def handoff_challenge
    cookies.encrypted[HANDOFF_COOKIE].presence
  end

  # `SameSite=None` because Apple's callback is a cross-site POST and a Lax
  # cookie would not be sent with it — the same reason, and the same shape, as
  # omniauth-apple's own `omniauth_apple_store` nonce cookie. That pairing
  # requires `Secure`, and therefore HTTPS: over plain http (a dev server on
  # 10.0.2.2) the cookie degrades to Lax, which is enough for GitHub's
  # same-site GET callback but not for Apple's. Apple sign-in cannot be tested
  # against an http origin either way, since its own nonce cookie is
  # unconditionally `Secure`.
  def remember_handoff_challenge(challenge)
    cookies.encrypted[HANDOFF_COOKIE] = {
      value: challenge,
      expires: HANDOFF_WINDOW.from_now,
      httponly: true,
      secure: request.ssl?,
      same_site: request.ssl? ? :none : :lax
    }
  end

  def forget_handoff_challenge
    cookies.delete(HANDOFF_COOKIE)
  end

  # Data structures that mimic OmniAuth::AuthHash for User.from_omniauth
  AuthInfo = Data.define(:email, :name)
  AuthHash = Data.define(:provider, :uid, :info)
end
