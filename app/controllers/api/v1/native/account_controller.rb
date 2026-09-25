module Api::V1::Native
  class AccountController < BaseController
    def show
      render json: { schema_version: 1, user: { id: user.id, email: user.email,
        native_language: user.native_language.iso_name, theme: user.theme,
        notification_delivery: user.notification_delivery, pro: user.pro?, beta: User.beta_pro?,
        credits: user.credit_balance, streak: ActivityLog.current_streak_for_user(user),
        total_xp: ActivityLog.total_xp_for_user(user) },
        languages: Language.order(:english_name).map { |row| serializer.language(row) },
        review_languages: user.languages_with_saved_words.map(&:iso_name),
        server_time: Time.zone.now.iso8601 }
    end

    def update
      permitted = params.permit(:native_language, :theme, notification_delivery: [])
      if permitted.key?(:native_language) && !User::NATIVE_LANGUAGE_CODES.include?(permitted[:native_language])
        raise ArgumentError, "Unsupported interface language"
      end
      user.with_lock { user.update!(permitted) }
      show
    end

    def destroy
      raise ArgumentError, "Confirm account deletion" unless params[:confirmation] == "DELETE"
      # Requires a fresh password proof; social accounts use the provider flow.
      unless user.valid_password?(params[:password].to_s)
        return render_error(:reauthentication_required, "Confirm your password before deleting your account", :unauthorized)
      end
      user.destroy!
      head :no_content
    end

    def extension_token
      app = Doorkeeper::Application.find_or_create_by!(uid: App::NativeTokensController::CLIENT_UID) do |row|
        row.name = "Langlets iOS Share"
        row.redirect_uri = "https://langlets.app/native"
        row.confidential = false
        row.scopes = App::NativeTokensController::SCOPES
      end
      token = user.oauth_access_tokens.where(application: app, revoked_at: nil)
        .where("created_at > ?", 29.days.ago).order(id: :desc).first
      token ||= Doorkeeper::AccessToken.create!(application: app, resource_owner_id: user.id,
        scopes: App::NativeTokensController::SCOPES, expires_in: 30.days.to_i)
      render json: { access_token: token.plaintext_token }
    end

    def device
      raise ArgumentError, "Invalid APNs environment" unless DeviceToken::ENVIRONMENTS.include?(params[:environment])
      DeviceToken.register!(user: user, token: params.require(:token), environment: params[:environment], app_version: params[:app_version])
      head :no_content
    end

    def remove_device
      user.device_tokens.where(token: params.require(:token)).delete_all
      head :no_content
    end
  end
end
