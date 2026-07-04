require "test_helper"

class Oauth::RegistrationThrottleTest < ActionDispatch::IntegrationTest
  setup do
    @original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rack::Attack.cache.store = @original_store
  end

  test "throttles repeated registrations from one IP" do
    5.times do
      post oauth_register_url, params: registration_params, as: :json
      assert_response :created
    end

    post oauth_register_url, params: registration_params, as: :json

    assert_response :too_many_requests
    body = JSON.parse(@response.body)
    assert_equal "rate_limited", body["error"]
    assert @response.headers["retry-after"].present?
  end

  private

  def registration_params
    {
      client_name: "Throttled agent",
      redirect_uris: [ "https://agent.example.com/callback" ],
      token_endpoint_auth_method: "none"
    }
  end
end
