class MakeSystemChannelSti < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE channels
      SET type = 'SystemChannel', visibility = 0
      WHERE visibility = 3
    SQL

    remove_index :channels, name: "idx_channels_one_system_channel"
    add_index :channels, :type, unique: true, where: "type = 'SystemChannel'",
      name: "idx_channels_one_system_channel"
  end

  def down
    remove_index :channels, name: "idx_channels_one_system_channel"

    execute <<~SQL
      UPDATE channels
      SET type = NULL, visibility = 3
      WHERE type = 'SystemChannel'
    SQL

    add_index :channels, :visibility, unique: true, where: "visibility = 3",
      name: "idx_channels_one_system_channel"
  end
end
