# frozen_string_literal: true

class AddAgentFieldsToOauthTables < ActiveRecord::Migration[8.0]
  def change
    # Doorkeeper doesn't track token usage; the connected-apps page shows it.
    add_column :oauth_access_tokens, :last_used_at, :datetime

    # Distinguishes clients created via RFC 7591 dynamic registration (/oauth/register)
    # from manually created applications.
    add_column :oauth_applications, :dynamically_registered, :boolean, null: false, default: false
  end
end
