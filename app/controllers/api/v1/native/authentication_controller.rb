module Api::V1::Native
  class AuthenticationController < ActionController::API
    rate_limit to: 10, within: 5.minutes, with: -> { render json: { error: "rate_limited" }, status: :too_many_requests }
    before_action -> { response.headers["Cache-Control"] = "no-store" }

    def onboarding
      render json: { beta: User.beta_pro?, languages: Language.order(:english_name).map { |row|
        { id: row.id, code: row.iso_name, name: row.english_name, native_name: row.native_name, rtl: !!row.rtl }
      }, examples: HomepageVideos.for_page.map { |video| { title: video.title, url: video.url, thumbnail_url: video.thumbnail_url } } }
    end

    def create
      user = if params[:google_code].present?
        identity = ::Native::GoogleIdentity.call(params[:google_code])
        User.from_omniauth(identity) if identity
      elsif params[:handoff].present?
        NativeAuthHandoff.redeem(params[:handoff], params[:verifier])
      else
        candidate = User.find_for_database_authentication(email: params[:email].to_s.strip.downcase)
        candidate if candidate&.valid_password?(params[:password].to_s)
      end
      if user&.active_for_authentication?
        render json: ::Native::Session.issue(user)
      else
        render json: { error: "invalid_credentials", error_description: "Check your credentials and confirm your email before signing in." }, status: :unauthorized
      end
    end

    def register
      user = User.new(params.permit(:email, :password, :password_confirmation))
      user.native_language = params[:native_language] if User::NATIVE_LANGUAGE_CODES.include?(params[:native_language])
      if user.save
        render json: { status: "confirmation_required" }, status: :created
      else
        render json: { error: "invalid_registration", error_description: user.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end

    def reset_password
      user = User.reset_password_by_token(params.permit(:reset_password_token, :password, :password_confirmation))
      if user.errors.empty?
        Doorkeeper::AccessToken.where(resource_owner_id: user.id, revoked_at: nil).update_all(revoked_at: Time.zone.now)
        render json: { status: "password_changed" }
      else
        render json: { error: "invalid_reset", error_description: user.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end

    def verify_confirmation
      user = User.confirm_by_token(params[:confirmation_token].to_s)
      if user.errors.empty?
        render json: { status: "confirmed" }
      else
        render json: { error: "invalid_confirmation", error_description: user.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end

    def recover
      User.send_reset_password_instructions(email: params[:email].to_s.strip.downcase)
      render json: { status: "email_sent" }
    end

    def confirm
      User.send_confirmation_instructions(email: params[:email].to_s.strip.downcase)
      render json: { status: "email_sent" }
    end
  end
end
