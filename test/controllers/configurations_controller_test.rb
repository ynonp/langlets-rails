require "test_helper"

class ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  # Each platform's served endpoint, the repo file behind it, and the copy
  # bundled into the app as its offline fallback.
  PLATFORMS = {
    "ios" => {
      endpoint: "/configurations/ios_v1.json",
      served: "config/hotwire/ios_path_configuration.json",
      bundled: "langlets-ios/langlets/langlets/Configuration/path_configuration.json"
    },
    "android" => {
      endpoint: "/configurations/android_v1.json",
      served: "config/hotwire/android_path_configuration.json",
      bundled: "langlets-android/app/src/main/assets/json/path_configuration.json"
    }
  }.freeze

  PLATFORMS.each do |platform, paths|
    test "serves the #{platform} path configuration as json" do
      get paths[:endpoint]

      assert_response :success
      config = JSON.parse(response.body)
      assert_kind_of Array, config["rules"]
      assert config["rules"].any?, "expected at least one routing rule"
    end

    # Both apps draw a native tab bar with one navigator per tab; a replace_root
    # rule on the tab roots would blow away a tab's stack on every in-app link to
    # one of them.
    test "the #{platform} tab roots carry no replace_root rule" do
      get paths[:endpoint]
      rules = JSON.parse(response.body)["rules"]

      tab_roots = [ "^/app$", "^/app/library$", "^/app/vocabulary$", "^/app/import_requests/new$" ]
      assert_not rules.any? { |rule|
        rule.dig("properties", "presentation") == "replace_root" &&
          (rule.fetch("patterns", []) & tab_roots).any?
      },
                 "tabs are native now — a replace_root rule would reset a tab's stack on every tab-root link"
    end

    test "the #{platform} authentication flow replaces the root instead of opening a modal" do
      rules = JSON.parse(File.read(Rails.root.join(paths[:served])))["rules"]
      auth_rule = rules.find { |rule| rule.fetch("patterns", []).include?("/users/sign_in") }

      assert auth_rule, "expected an authentication routing rule"
      assert_equal "default", auth_rule.dig("properties", "context")
      assert_equal "replace_root", auth_rule.dig("properties", "presentation")
      assert auth_rule.fetch("patterns").any? { |pattern| Regexp.new(pattern).match?("/users/sign_up/check_email") },
             "expected the post-signup check-email page to stay in the authentication root"
      assert_includes auth_rule.fetch("patterns"), "/users/confirmation/new"
    end

    # The trap this guards: ConfigurationsController inherits ActionController::API
    # rather than ApplicationController. Under ApplicationController,
    # require_authentication_for_native_app would answer a signed-out native request
    # with a redirect to /users/sign_in, and Hotwire Native would try to parse the
    # sign-in HTML as path configuration.
    test "serves #{platform} json to a signed-out native app instead of redirecting to sign in" do
      get paths[:endpoint], headers: { "User-Agent" => "LangletsNative" }

      assert_response :success
      assert_nothing_raised { JSON.parse(response.body) }
      assert JSON.parse(response.body)["rules"].any?
    end

    test "the #{platform} response is publicly cacheable" do
      get paths[:endpoint]

      assert_match(/max-age/, response.headers["Cache-Control"].to_s)
      assert_match(/public/, response.headers["Cache-Control"].to_s)
    end

    # The bundled copy is the app's offline fallback and first-launch seed. The
    # server copy wins at runtime, but letting the two drift in the repo means
    # offline launches silently use stale routing rules.
    test "the bundled #{platform} fallback matches the served configuration" do
      served  = JSON.parse(File.read(Rails.root.join(paths[:served])))
      bundled = JSON.parse(File.read(Rails.root.join(paths[:bundled])))

      assert_equal served, bundled,
                   "#{paths[:bundled]} has drifted from #{paths[:served]} — update both together"
    end

    # Merging is order-dependent and the order is the opposite of what it looks
    # like: both platforms apply the properties of *every* matching rule, with
    # later rules winning, and patterns are unanchored regexes. A catch-all
    # anywhere but first silently overwrites every modal rule above it.
    test "the #{platform} catch-all rule comes first" do
      rules = JSON.parse(File.read(Rails.root.join(paths[:served])))["rules"]

      assert_includes rules.first.fetch("patterns"), ".*",
                      "the catch-all must be the first rule — later rules override earlier ones"
      assert_not rules.drop(1).any? { |rule| rule.fetch("patterns", []).include?(".*") },
                 "a second catch-all would override every specific rule above it"
    end
  end

  # Android matches patterns against "path?query" whenever a query is present
  # (PathConfigurationData#path), and unlike iOS there is no matchQueryStrings
  # switch to turn that off. Since this app appends ?lang= to nearly every link, a
  # bare `$` anchor never matches in practice and the screen quietly presents as a
  # plain push instead of a modal. There is no runtime error to notice, so the
  # suffix is asserted here instead.
  test "android anchored patterns tolerate a query string" do
    rules = JSON.parse(File.read(Rails.root.join("config/hotwire/android_path_configuration.json")))["rules"]
    patterns = rules.flat_map { |rule| rule.fetch("patterns", []) }

    offenders = patterns.select { |pattern| pattern.end_with?("$") && !pattern.end_with?('(\?.*)?$') }

    assert_empty offenders,
                 "these Android patterns end in a bare `$`, so they can never match a URL carrying " \
                 "?lang=: #{offenders.inspect}. End them with (\\?.*)?$ instead."
  end

  # The two files encode the same routing decisions in two dialects. Rule *count*
  # drifting means one platform gained or lost a screen behaviour the other did
  # not — the most common way these two fall out of step.
  test "both platforms describe the same set of rules" do
    ios = JSON.parse(File.read(Rails.root.join("config/hotwire/ios_path_configuration.json")))["rules"]
    android = JSON.parse(File.read(Rails.root.join("config/hotwire/android_path_configuration.json")))["rules"]

    assert_equal ios.length, android.length,
                 "one platform's path configuration gained or lost a rule the other didn't — " \
                 "they should express the same routing decisions"

    ios.zip(android).each_with_index do |(ios_rule, android_rule), index|
      assert_equal ios_rule.dig("properties", "context"),
                   android_rule.dig("properties", "context"),
                   "rule ##{index} presents differently on the two platforms"
    end
  end
end
