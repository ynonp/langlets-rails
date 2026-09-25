class AddNextPracticeTime < ActiveRecord::Migration[8.0]
  def up
    add_column :starter_challenges, :next_practice_at, :datetime
    execute <<~SQL
      UPDATE starter_challenges
      SET next_practice_at = ((first_challenge_on + 5) + make_interval(mins => reminder_minute)) AT TIME ZONE reminder_timezone
    SQL
    change_column_null :starter_challenges, :next_practice_at, false
    add_index :starter_challenges, :next_practice_at
  end

  def down
    remove_column :starter_challenges, :next_practice_at
  end
end
