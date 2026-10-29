class AllowVocabularyScopeUpgradesForAgentClients < ActiveRecord::Migration[8.0]
  def up
    # Only extend client capabilities. Existing grants and tokens are untouched;
    # the user must approve a new authorization before a client can write.
    execute <<~SQL
      UPDATE oauth_applications
      SET scopes = scopes || ' vocabulary:write'
      WHERE dynamically_registered = TRUE
        AND 'vocabulary:read' = ANY(string_to_array(scopes, ' '))
        AND NOT ('vocabulary:write' = ANY(string_to_array(scopes, ' ')))
    SQL
  end

  def down
    # Preserve registrations and authorizations created since this migration.
  end
end
