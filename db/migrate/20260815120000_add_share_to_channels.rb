class AddShareToChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :channels, :share, :boolean, null: false, default: false
    add_index :channels, :user_id, unique: true, where: '"share" = TRUE',
      name: "idx_channels_one_share_per_user"
  end
end
