module Native
  class Session
    CLIENT_UID = "langlets-ios-native-v1".freeze
    SCOPES = "native imports:read imports:write credits:read".freeze

    def self.issue(user)
      application = Doorkeeper::Application.find_or_create_by!(uid: CLIENT_UID) do |app|
        app.name = "Langlets iOS native"
        app.redirect_uri = "https://langlets.app/native"
        app.confidential = false
        app.scopes = SCOPES
      end
      token = Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id,
        scopes: SCOPES, expires_in: 2.hours.to_i, use_refresh_token: true)
      { access_token: token.plaintext_token, refresh_token: token.plaintext_refresh_token,
        client_id: application.uid, expires_in: token.expires_in, user_id: user.id }
    end
  end
end
