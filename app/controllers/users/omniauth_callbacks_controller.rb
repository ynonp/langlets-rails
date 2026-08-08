# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Devise::Controllers::Rememberable

  # Apple delivers its callback as a cross-site form POST, which carries no
  # Rails CSRF token. OmniAuth dispatches callback errors to #failure using the
  # same request, so that action must be exempt as well or the OAuth error gets
  # replaced by an InvalidAuthenticityToken response.
  skip_before_action :verify_authenticity_token, only: [ :native_google, :native_apple, :apple, :failure ]

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
      redirect_to "langlets://auth-failure", allow_other_host: true
    else
      redirect_to root_path
    end
  end

  def native_success
    if user_signed_in?
      url = "langlets://auth-success"
      url = "#{url}?ios_lang=#{CGI.escape(current_user.ios_lang)}" if current_user.ios_lang.present?
      redirect_to url, allow_other_host: true
    else
      redirect_to "langlets://auth-failure", allow_other_host: true
    end
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

  def native_app?
    request.user_agent&.include?("LangletsNative") ||
      request.env["omniauth.params"]&.dig("native_app").present?
  end

  # Data structures that mimic OmniAuth::AuthHash for User.from_omniauth
  AuthInfo = Data.define(:email, :name)
  AuthHash = Data.define(:provider, :uid, :info)
end
