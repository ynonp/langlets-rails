require "test_helper"

class NPlusOneFixTest < ActionDispatch::IntegrationTest
  test "lesson show action does not have N+1 queries for script variants" do
    # Skip if no lessons exist in test database
    lesson = Lesson.first
    skip "No lessons available in test database" unless lesson

    # Capture queries to verify N+1 is fixed
    queries = []
    callback = ->(name, started, finished, unique_id, payload) {
      if payload[:sql] && payload[:sql].include?("script_variants")
        queries << payload[:sql]
      end
    }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get lesson_path(lesson.slug)
    end

    # We should see at most a few bulk queries for script_variants, not individual queries
    individual_script_variant_queries = queries.select do |query|
      query.include?("WHERE") && 
      query.include?("script_variants") && 
      query.include?("multi_script_text_id") &&
      !query.include?("IN (")  # Exclude bulk queries with IN clause
    end

    # Should have 0 individual script variant queries (all should be bulk queries)
    assert_equal 0, individual_script_variant_queries.length,
      "Found #{individual_script_variant_queries.length} individual script variant queries, " \
      "which indicates N+1 queries are not fixed:\n#{individual_script_variant_queries.join("\n")}"
  end
end