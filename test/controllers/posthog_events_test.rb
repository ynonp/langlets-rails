require "test_helper"

class PosthogEventsTest < ActionDispatch::IntegrationTest
  test "guest page views use one session identity without query parameters" do
    events = []
    PostHog.stub(:capture, ->(event) { events << event }) do
      get home_privacy_path, params: { token: "private-value" }
      get home_terms_path
    end

    assert_response :success
    assert_equal [ "$pageview", "$pageview" ], events.map { |event| event[:event] }
    assert_equal [ home_privacy_path, home_terms_path ], events.map { |event| event[:properties][:path] }
    assert_equal [
      "http://www.example.com/home/privacy",
      "http://www.example.com/home/terms"
    ], events.map { |event| event[:properties]["$current_url"] }
    assert_equal events.first[:distinct_id], events.last[:distinct_id]
    refute_includes events.to_s, "private-value"
  end
end
