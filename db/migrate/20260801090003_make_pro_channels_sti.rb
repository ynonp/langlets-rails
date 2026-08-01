class MakeProChannelsSti < ActiveRecord::Migration[8.0]
  # A Pro library is a Channel the subscriber owns, distinguished by STI rather
  # than by pointing at a beneficiary from a channel somebody else owns.
  #
  # The first cut had the platform administrator own it so that access could be
  # withdrawn by deleting a ChannelSubscription. That worked, but it stored the
  # entitlement twice — once in `subscriptions`, once as a ChannelSubscription
  # mirroring it — and copies drift. Access is now derived from the subscription
  # itself in ProChannel.owned_grant, so there is nothing to keep in step, no
  # dependency on an administrator account existing, and no reason the
  # administrator cannot subscribe like anybody else.
  def up
    add_column :channels, :type, :string
    add_index :channels, :type

    # Hand any Pro library built under the previous shape to its subscriber.
    # Empty in production — this shipped in one batch — but development
    # databases have already run the previous migration.
    execute <<~SQL
      DELETE FROM channel_subscriptions
      WHERE channel_id IN (SELECT id FROM channels WHERE pro_subscriber_id IS NOT NULL)
    SQL
    execute <<~SQL
      UPDATE channels
      SET type = 'ProChannel', user_id = pro_subscriber_id, visibility = 0
      WHERE pro_subscriber_id IS NOT NULL
    SQL

    remove_column :channels, :pro_subscriber_id

    # One Pro library per subscriber. Ordinary channels have a NULL type and are
    # outside the index entirely, so this cannot collide with the existing
    # one-default-per-user index.
    add_index :channels, :user_id, unique: true, where: "type = 'ProChannel'",
              name: "idx_channels_one_pro_channel_per_user"
  end

  def down
    remove_index :channels, name: "idx_channels_one_pro_channel_per_user"
    add_reference :channels, :pro_subscriber, null: true, foreign_key: { to_table: :users }, index: false
    add_index :channels, :pro_subscriber_id, unique: true, where: "pro_subscriber_id IS NOT NULL",
              name: "idx_channels_one_pro_channel_per_subscriber"
    remove_index :channels, :type
    remove_column :channels, :type
  end
end
