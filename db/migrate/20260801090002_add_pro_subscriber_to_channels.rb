class AddProSubscriberToChannels < ActiveRecord::Migration[8.0]
  # A Pro subscriber's library lives in a Channel of its own, and the point of it
  # is that access is *lent*, not owned: cancelling Pro removes the
  # ChannelSubscription and the library goes dark until they come back.
  #
  # That is why the channel is owned by the platform administrator and merely
  # *points at* its subscriber through this column, rather than belonging to
  # them through `user_id`. Channel.visible_to grants an owner their own channels
  # unconditionally, and ChannelSubscription refuses to let anyone subscribe to a
  # channel they own — so a self-owned Pro channel could not be switched off at
  # all. Keeping the two roles in two columns means none of the authorization
  # rules need a Pro exception.
  def change
    add_reference :channels, :pro_subscriber, null: true, foreign_key: { to_table: :users }, index: false

    # One Pro library per subscriber; ordinary channels leave the column NULL and
    # are outside the index entirely.
    add_index :channels, :pro_subscriber_id, unique: true, where: "pro_subscriber_id IS NOT NULL",
              name: "idx_channels_one_pro_channel_per_subscriber"
  end
end
