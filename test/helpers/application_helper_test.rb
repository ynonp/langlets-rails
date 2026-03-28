# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # Mock request object for testing
  class MockRequest
    attr_accessor :user_agent
    def initialize(user_agent)
      @user_agent = user_agent
    end
  end

  test "turbo_native_app? returns true for Turbo Native user agent" do
    @request = MockRequest.new("Turbo Native iOS")
    def request; @request; end
    assert turbo_native_app?
  end

  test "turbo_native_app? returns false for regular browser" do
    @request = MockRequest.new("Mozilla/5.0 Chrome/120.0")
    def request; @request; end
    refute turbo_native_app?
  end

  test "turbo_native_ios? returns true for iOS user agent" do
    @request = MockRequest.new("Turbo Native iOS/1.0")
    def request; @request; end
    assert turbo_native_ios?
  end

  test "turbo_native_android? returns true for Android user agent" do
    @request = MockRequest.new("Turbo Native Android/1.0")
    def request; @request; end
    assert turbo_native_android?
  end

  test "turbo_native_android? returns false for regular browser" do
    @request = MockRequest.new("Mozilla/5.0 Chrome/120.0")
    def request; @request; end
    refute turbo_native_android?
  end
end
