class CreateActivityLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :active_time
      t.integer :xp_gained
      t.references :lesson, null: true, foreign_key: true

      t.timestamps
    end
  end
end
