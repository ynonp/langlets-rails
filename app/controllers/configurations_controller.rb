# Serves the Hotwire Native path configuration to the native apps.
#
# Each app loads [.file(bundled), .server(this)], so this copy wins at runtime and
# routing rules (which screens are modals, which get pull-to-refresh) can change
# without shipping a build. The bundled copies in
# langlets-ios/langlets/langlets/Configuration/path_configuration.json and
# langlets-android/app/src/main/assets/json/path_configuration.json are only the
# offline fallback and the first-launch seed; tests keep each in step with its
# served file.
#
# There are two files rather than one because Android's path configuration needs
# a per-rule `uri` naming the Fragment destination to build, and its patterns are
# matched against the query string as well as the path — neither of which has an
# iOS equivalent. The routing *decisions* are the same on both; the encoding of
# them is not. See the comment blocks inside each JSON file.
#
# Inherits ActionController::API rather than ApplicationController on purpose:
# ApplicationController's require_authentication_for_native_app would answer a
# signed-out native request with a redirect to the sign-in page, and the app would
# try to parse that HTML as path configuration.
class ConfigurationsController < ActionController::API
  IOS_PATH = Rails.root.join("config", "hotwire", "ios_path_configuration.json")
  ANDROID_PATH = Rails.root.join("config", "hotwire", "android_path_configuration.json")

  def ios_v1
    render_configuration(IOS_PATH)
  end

  def android_v1
    render_configuration(ANDROID_PATH)
  end

  private

  def render_configuration(path)
    expires_in 5.minutes, public: true
    render json: File.read(path)
  end
end
