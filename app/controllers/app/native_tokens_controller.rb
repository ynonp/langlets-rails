module App
  # A share extension cannot read the containing WKWebView's session cookies.
  # The authenticated app page calls this endpoint and hands the resulting
  # narrow bearer token to Swift through a Hotwire Native bridge component.
  class NativeTokensController < BaseController
    TOKEN_LIFETIME = 30.days
    SCOPES = "imports:read imports:write credits:read".freeze
    CLIENT_UID = "langlets-ios-share-extension".freeze

    def create
      token = reusable_token || issue_token

      render json: {
        access_token: token.plaintext_token,
        expires_at: Time.zone.at(token.created_at.to_i + token.expires_in).iso8601,
        scopes: token.scopes.to_s,
        languages: Language.order(:english_name).map { |language|
          { iso_name: language.iso_name, english_name: language.english_name }
        }
      }
    end

    private

    def reusable_token
      current_user.oauth_access_tokens
                  .where(application: native_application, revoked_at: nil, scopes: SCOPES)
                  .where("created_at > ?", Time.zone.now - 29.days)
                  .order(created_at: :desc)
                  .first
                  &.then { |token| token unless token.expired? }
    end

    def issue_token
      Doorkeeper::AccessToken.create!(
        application: native_application,
        resource_owner_id: current_user.id,
        scopes: SCOPES,
        expires_in: TOKEN_LIFETIME.to_i
      )
    end

    def native_application
      @native_application ||= Doorkeeper::Application.find_or_create_by!(uid: CLIENT_UID) do |application|
        application.name = "Langlets iOS"
        application.redirect_uri = "https://langlets.app/native"
        application.scopes = SCOPES
        application.confidential = false
      end
    rescue ActiveRecord::RecordNotUnique
      retry
    end
  end
end
