# Serves the Hotwire Native path configuration to the iOS app.
#
# The app loads [.file(bundled), .server(this)], so this copy wins at runtime and
# routing rules (which screens are modals, which get pull-to-refresh) can change
# without shipping a build. The bundled copy in
# langlets-ios/langlets/langlets/Configuration/path_configuration.json is only the
# offline fallback and the first-launch seed; a test keeps the two in step.
#
# Inherits ActionController::API rather than ApplicationController on purpose:
# ApplicationController's require_authentication_for_native_app would answer a
# signed-out native request with a redirect to the sign-in page, and the app would
# try to parse that HTML as path configuration.
class ConfigurationsController < ActionController::API
  PATH = Rails.root.join("config", "hotwire", "ios_path_configuration.json")

  def ios_v1
    expires_in 5.minutes, public: true
    render json: File.read(PATH)
  end
end
