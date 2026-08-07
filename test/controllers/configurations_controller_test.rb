require "test_helper"

class ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  test "serves the path configuration as json" do
    get "/configurations/ios_v1.json"

    assert_response :success
    config = JSON.parse(response.body)
    assert_kind_of Array, config["rules"]
    assert config["rules"].any?, "expected at least one routing rule"
  end

  # The app's tab bar is a native UITabBarController with one navigator per tab;
  # a replace_root rule on the tab roots would blow away a tab's stack on every
  # in-app link to one of them.
  test "the tab roots carry no replace_root rule" do
    get "/configurations/ios_v1.json"
    rules = JSON.parse(response.body)["rules"]

    tab_roots = ["^/app$", "^/app/library$", "^/app/import_requests/new$"]
    assert_not rules.any? { |rule|
      rule.dig("properties", "presentation") == "replace_root" &&
        (rule.fetch("patterns", []) & tab_roots).any?
    },
               "tabs are native now — a replace_root rule would reset a tab's stack on every tab-root link"
  end

  # The trap this guards: ConfigurationsController inherits ActionController::API
  # rather than ApplicationController. Under ApplicationController,
  # require_authentication_for_native_app would answer a signed-out native request
  # with a redirect to /users/sign_in, and Hotwire Native would try to parse the
  # sign-in HTML as path configuration.
  test "serves json to a signed-out native app instead of redirecting to sign in" do
    get "/configurations/ios_v1.json", headers: { "User-Agent" => "LangletsNative" }

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
