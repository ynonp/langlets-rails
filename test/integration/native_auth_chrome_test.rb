require "test_helper"

class NativeAuthChromeTest < ActionDispatch::IntegrationTest
  NATIVE_HEADERS = { "User-Agent" => "LangletsNative" }.freeze

  test "native login hides the tab bar and has no close control" do
    get new_user_session_path, headers: NATIVE_HEADERS

    assert_response :success
    assert_select '[data-controller="bridge--tab-visibility"][data-bridge--tab-visibility-visible-value="false"]'
    assert_select '[data-testid="auth-close"]', count: 0
  end

  test "native signup hides the tab bar and has no close control" do
    get new_user_registration_path, headers: NATIVE_HEADERS

    assert_response :success
    assert_select '[data-controller="bridge--tab-visibility"][data-bridge--tab-visibility-visible-value="false"]'
    assert_select '[data-testid="auth-close"]', count: 0
  end

  test "web authentication keeps its close control and does not send native chrome messages" do
    get new_user_session_path

    assert_response :success
    assert_select '[data-controller="bridge--tab-visibility"]', count: 0
    assert_select '[data-testid="auth-close"]', count: 1
  end
end
