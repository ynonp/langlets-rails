require "test_helper"

class ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  test "serves the path configuration as json" do
    get "/configurations/ios_v1.json"

    assert_response :success
    config = JSON.parse(response.body)
    assert_kind_of Array, config["rules"]
    assert config["rules"].any?, "expected at least one routing rule"
  end

  # The trap this guards: ConfigurationsController inherits ActionController::API
  # rather than ApplicationController. Under ApplicationController,
  # require_authentication_for_native_app would answer a signed-out native request
  # with a redirect to /users/sign_in, and Hotwire Native would try to parse the
  # sign-in HTML as path configuration.
  test "serves json to a signed-out native app instead of redirecting to sign in" do
    get "/configurations/ios_v1.json", headers: { "User-Agent" => "LangletsNative/1.0" }

    assert_response :success
    assert_nothing_raised { JSON.parse(response.body) }
    assert JSON.parse(response.body)["rules"].any?
  end

  test "response is publicly cacheable" do
    get "/configurations/ios_v1.json"

    assert_match(/max-age/, response.headers["Cache-Control"].to_s)
    assert_match(/public/, response.headers["Cache-Control"].to_s)
  end

  # The bundled copy is the app's offline fallback and first-launch seed. The
  # server copy wins at runtime, but letting the two drift in the repo means
  # offline launches silently use stale routing rules.
  test "the bundled iOS fallback matches the served configuration" do
    served  = JSON.parse(File.read(Rails.root.join("config/hotwire/ios_path_configuration.json")))
    bundled = JSON.parse(File.read(Rails.root.join("langlets-ios/langlets/langlets/Configuration/path_configuration.json")))

    assert_equal served, bundled,
                 "langlets-ios .../Configuration/path_configuration.json has drifted from " \
                 "config/hotwire/ios_path_configuration.json — update both together"
  end
end
