class CreateStarterChallenges < ActiveRecord::Migration[8.0]
  def change
    create_table :starter_challenges do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.datetime :started_at, null: false
      t.timestamps
    end
    create_table :starter_challenge_languages do |t|
      t.references :starter_challenge, null: false, foreign_key: true
      t.references :language, null: false, foreign_key: true
      t.index [:starter_challenge_id, :language_id], unique: true
    end
    create_table :daily_challenges do |t|
      t.references :starter_challenge, null: false, foreign_key: true
      t.integer :day, null: false
      t.datetime :available_at, null: false
      t.references :notification, foreign_key: { on_delete: :nullify }
      t.datetime :skipped_at
      t.datetime :completed_at
      t.timestamps
      t.index [:starter_challenge_id, :day], unique: true
      t.index :available_at, where: 'notification_id IS NULL AND skipped_at IS NULL'
      t.check_constraint 'day BETWEEN 1 AND 5', name: 'daily_challenge_day_range'
    end
  end
end
