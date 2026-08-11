class AddSystemVisibilityToChannels < ActiveRecord::Migration[8.0]
  def up
    remove_check_constraint :channels, name: "channels_visibility_valid"
    add_check_constraint :channels, "visibility IN (0, 1, 2, 3)",
      name: "channels_visibility_valid"
    add_index :channels, :visibility, unique: true, where: "visibility = 3",
      name: "idx_channels_one_system_channel"
  end

  def down
    remove_index :channels, name: "idx_channels_one_system_channel"
    remove_check_constraint :channels, name: "channels_visibility_valid"
    execute "UPDATE channels SET visibility = 2 WHERE visibility = 3"
    add_check_constraint :channels, "visibility IN (0, 1, 2)",
      name: "channels_visibility_valid"
  end
end
