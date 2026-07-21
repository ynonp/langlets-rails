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

  # Accepts a Google serverAuthCode from the native iOS app (Google Sign-In SDK)
  # and exchanges it for an access token, then signs the user in.
  def native_google
    code = params[:code]
    redirect_uri = params[:redirect_uri].presence || ""

    if code.blank?
      redirect_to new_user_session_path, alert: "Missing authorization code"
      return
    end

    # Exchange the code with Google for tokens
    token_response = exchange_google_code(code, redirect_uri)

    if token_response["access_token"].blank?
      Rails.logger.error "Google token exchange failed: #{token_response.inspect}"
      redirect_to new_user_session_path, alert: "Google authentication failed"
      return
    end

    # Fetch user info from Google
    user_info = fetch_google_user_info(token_response["access_token"])

    if user_info["email"].blank?
      Rails.logger.error "Google user info missing email: #{user_info.inspect}"
      redirect_to new_user_session_path, alert: "Could not retrieve user info"
      return
    end

    # Build an OmniAuth-style auth hash and sign the user in
    info = AuthInfo.new(email: user_info["email"], name: user_info["name"])
    auth = AuthHash.new(provider: "google_oauth2", uid: user_info["id"], info: info)

    @user = User.from_omniauth(auth)

    if @user.persisted?
      sign_in(@user, event: :authentication)
      remember_me(@user)
      redirect_to root_path
    else
      session["devise.google_data"] = { info: { email: user_info["email"] } }
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
