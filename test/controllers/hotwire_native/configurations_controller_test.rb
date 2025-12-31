# frozen_string_literal: true

require "test_helper"

class HotwireNative::ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  test "returns valid JSON" do
    get "/hotwire_native/path-configuration"
    assert_response :success
    assert_includes response.content_type, "application/json"
  end

  test "includes settings and rules keys" do
    get "/hotwire_native/path-configuration"
    json = JSON.parse(response.body)
    assert json.key?("settings")
    assert json.key?("rules")
    assert_kind_of Array, json["rules"]
    assert json["rules"].first.key?("patterns")
    assert json["rules"].first.key?("properties")
  end

  test "does not require CSRF token" do
    get "/hotwire_native/path-configuration", headers: { "X-CSRF-Token" => "" }
    assert_response :success
  end
end
