class CreateNotifications < ActiveRecord::Migration[8.0]
  # There is already a `notifications` table in schema.rb — an orphan from an
  # abandoned attempt: no migration ever created it, no model ever read it, and
  # nothing in the app writes to it, so it is empty everywhere. It is dropped
  # rather than altered because its shape (string kind, `cleared_at`, no copy
  # columns) is not the one this subsystem needs. The count check is there so a
  # database that somehow does hold rows fails loudly instead of losing them.
  def up
    if table_exists?(:notifications)
      rows = select_value("SELECT COUNT(*) FROM notifications").to_i
      raise "Refusing to drop notifications: #{rows} rows present" if rows.positive?

      drop_table :notifications
    end

    create_notifications
  end

  def down
    drop_table :notifications
  end

  private

  def create_notifications
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true

      # What happened. Persisted as an integer; keep the values stable.
      t.integer :kind, null: false

      # The copy is denormalized onto the row rather than rebuilt on render:
      # email, push and the notifications page must say the same thing, and a
      # notification has to survive the course it is about being deleted.
      t.string :title, null: false
      t.string :body, null: false
      t.string :url

      # Anything a client needs beyond the copy — course_slug for the iOS deep
      # link, the failure reason for the email's details block.
      t.jsonb :data, null: false, default: {}

      # sent_at: delivery was attempted (email/push, per the user's preference).
      # read_at: the user has seen it. Both nullable and independent.
      t.datetime :sent_at
      t.datetime :read_at

      t.timestamps
    end

    # The list, newest first.
    add_index :notifications, [ :user_id, :created_at ]
    # The unread badge, on every authenticated page.
    add_index :notifications, [ :user_id, :read_at ]
  end
end
