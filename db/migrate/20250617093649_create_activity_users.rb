class CreateActivityUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_users do |t|
      t.references :activity, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :activity_users, [:activity_id, :user_id], unique: true
  end
end
