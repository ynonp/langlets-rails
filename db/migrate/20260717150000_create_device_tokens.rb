class CreateDeviceTokens < ActiveRecord::Migration[8.0]
  # Where to send "your course is ready".
  def change
    create_table :device_tokens do |t|
      t.references :user, null: false, foreign_key: true

      # The APNs device token, hex.
      t.string :token, null: false

      t.integer :platform, null: false, default: 0

      # Sandbox tokens are only valid against api.sandbox.push.apple.com and
      # production tokens only against api.push.apple.com — sending to the wrong
      # host is a BadDeviceToken. A debug build and a TestFlight build on the same
      # phone produce different tokens, so this is per-row, not global config.
      t.string :environment, null: false, default: "production"

      t.string :app_version
      t.datetime :last_seen_at

      # Apple told us this token is dead (410 / Unregistered). Kept rather than
      # deleted so "why did I stop getting pushes?" is answerable.
      t.datetime :invalidated_at

      t.timestamps
    end

    # Unique GLOBALLY, not scoped to the user, and that matters: a device token
    # identifies a *device*, and a phone can change hands (sign out, someone else
    # signs in). Scoped per-user, both rows would survive and we'd push user A's
    # course titles to a phone now held by user B. Global lets the row move.
    add_index :device_tokens, :token, unique: true
    add_index :device_tokens, [ :user_id, :invalidated_at ]
  end
end
