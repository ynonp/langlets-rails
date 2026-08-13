class RemoveUserTargetLanguage < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE users
      SET preferences = preferences - 'ios_lang'
      WHERE preferences ? 'ios_lang'
    SQL

    remove_reference :users, :preferred_language, foreign_key: { to_table: :languages }
  end

  def down
    add_reference :users, :preferred_language, foreign_key: { to_table: :languages }
  end
end
