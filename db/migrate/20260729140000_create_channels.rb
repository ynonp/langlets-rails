class CreateChannels < ActiveRecord::Migration[8.0]
  def up
    unless table_exists?(:channels)
      create_table :channels do |t|
        t.references :user, null: false, foreign_key: true
        t.string :name, null: false
        t.string :slug, null: false
        t.integer :visibility, null: false, default: 0
        t.boolean :default, null: false, default: false
        t.timestamps
      end
    end
    remove_column :channels, :system if column_exists?(:channels, :system)
    remove_column :channels, :default_subscription if column_exists?(:channels, :default_subscription)
    change_column_null :channels, :user_id, false
    add_foreign_key :channels, :users unless foreign_key_exists?(:channels, :users)
    add_index :channels, :slug, unique: true unless index_exists?(:channels, :slug, unique: true)
    add_index :channels, [ :visibility, :created_at ] unless index_exists?(:channels, [ :visibility, :created_at ])
    unless index_name_exists?(:channels, "index_channels_on_user_id_where_default")
      add_index :channels, :user_id, unique: true, where: '"default" = TRUE',
        name: "index_channels_on_user_id_where_default"
    end
    unless check_constraint_exists?(:channels, name: "channels_visibility_valid")
      add_check_constraint :channels, "visibility IN (0, 1, 2)",
        name: "channels_visibility_valid"
    end

    unless table_exists?(:channel_items)
      create_table :channel_items do |t|
        t.references :channel, null: false, foreign_key: true
        t.references :course, null: false, foreign_key: true
        t.datetime :published_at, null: false
        t.timestamps
      end
    end
    add_index :channel_items, [ :channel_id, :course_id ], unique: true unless index_exists?(:channel_items, [ :channel_id, :course_id ], unique: true)
    add_index :channel_items, [ :channel_id, :published_at ] unless index_exists?(:channel_items, [ :channel_id, :published_at ])

    unless table_exists?(:channel_subscriptions)
      create_table :channel_subscriptions do |t|
        t.references :channel, null: false, foreign_key: true
        t.references :user, null: false, foreign_key: true
        t.timestamps
      end
    end
    add_index :channel_subscriptions, [ :channel_id, :user_id ], unique: true unless index_exists?(:channel_subscriptions, [ :channel_id, :user_id ], unique: true)
    add_index :channel_subscriptions, [ :user_id, :created_at ] unless index_exists?(:channel_subscriptions, [ :user_id, :created_at ])

    create_table :channel_invitations do |t|
      t.references :channel, null: false, foreign_key: true
      t.references :inviter, null: false, foreign_key: { to_table: :users }
      t.references :invitee, null: true, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :token_digest, null: false
      t.integer :status, null: false, default: 0
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.timestamps
    end
    add_index :channel_invitations, :token_digest, unique: true
    add_index :channel_invitations, [ :channel_id, :email ], unique: true,
      where: "status = 0", name: "index_channel_invitations_pending_email"
    add_index :channel_invitations, [ :invitee_id, :status ]
    add_index :channel_invitations, [ :email, :status ]
    add_check_constraint :channel_invitations, "status IN (0, 1, 2, 3, 4)",
      name: "channel_invitations_status_valid"

    # SQL-only, restart-safe historical provisioning. The persisted name is
    # neutral data; presentation copy is localized at render time.
    execute <<~SQL
      INSERT INTO channels (user_id, name, slug, visibility, "default", created_at, updated_at)
      SELECT users.id, 'My Channel', 'channel-' || users.id, 0, TRUE, NOW(), NOW()
      FROM users
      WHERE NOT EXISTS (
        SELECT 1 FROM channels WHERE channels.user_id = users.id AND channels."default" = TRUE
      )
      ON CONFLICT DO NOTHING
    SQL

    execute <<~SQL
      INSERT INTO channel_items (channel_id, course_id, published_at, created_at, updated_at)
      SELECT channels.id, import_requests.course_id, MIN(import_requests.updated_at), NOW(), NOW()
      FROM import_requests
      INNER JOIN channels
        ON channels.user_id = import_requests.user_id AND channels."default" = TRUE
      INNER JOIN courses
        ON courses.id = import_requests.course_id
      WHERE import_requests.status = 2 AND courses.status = 1
      GROUP BY channels.id, import_requests.course_id
      ON CONFLICT (channel_id, course_id) DO NOTHING
    SQL
  end

  def down
    drop_table :channel_invitations
    drop_table :channel_subscriptions
    drop_table :channel_items
    drop_table :channels
  end
end
