require "test_helper"
require Rails.root.join("db/migrate/20261029130000_allow_vocabulary_scope_upgrades_for_agent_clients")

class AgentClientScopeUpgradeTest < ActiveSupport::TestCase
  test "upgrades only dynamic vocabulary clients without changing existing tokens" do
    dynamic = create_oauth_app
    dynamic.update!(dynamically_registered: true)
    static = create_oauth_app
    courses_only = create_oauth_app
    courses_only.update!(dynamically_registered: true, scopes: "courses:read")
    user = User.create!(email: "migration-agent@example.com", password: "password123", confirmed_at: Time.zone.now)
    token = create_access_token(user, application: dynamic)
    original_scopes = token.scopes.to_s

    migration = AllowVocabularyScopeUpgradesForAgentClients.new
    migration.suppress_messages { migration.up }
    assert_includes dynamic.reload.scopes.to_a, "vocabulary:write"
    assert_not_includes static.reload.scopes.to_a, "vocabulary:write"
    assert_not_includes courses_only.reload.scopes.to_a, "vocabulary:write"
    assert_equal original_scopes, token.reload.scopes.to_s

    migration.suppress_messages { migration.up }
    assert_equal 1, dynamic.reload.scopes.to_a.count("vocabulary:write")
  end
end
