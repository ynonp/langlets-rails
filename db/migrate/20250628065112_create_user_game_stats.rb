class CreateUserGameStats < ActiveRecord::Migration[8.0]
  def change
    create_table :user_game_stats do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :total_xp, default: 0
      t.integer :current_streak, default: 0
      t.date :last_activity_date
      t.integer :daily_xp, default: 0

      t.timestamps
    end
    
    remove_index :user_game_stats, :user_id
    add_index :user_game_stats, :user_id, unique: true
  end
end
