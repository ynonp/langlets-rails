class AddChallengeReminderSchedule < ActiveRecord::Migration[8.0]
  def change
    add_column :starter_challenges, :reminder_minute, :integer, default: 540, null: false
    add_column :starter_challenges, :reminder_timezone, :string, default: "UTC", null: false
    add_check_constraint :starter_challenges, "reminder_minute BETWEEN 0 AND 1439", name: "starter_challenge_reminder_minute_range"

    create_table :daily_practice_reminders do |t|
      t.references :starter_challenge, null: false, foreign_key: true
      t.date :local_date, null: false
      t.references :notification, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
      t.index [ :starter_challenge_id, :local_date ], unique: true
    end
    add_index :starter_challenges, :started_at
  end
end
