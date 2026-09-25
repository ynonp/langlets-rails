class AddFirstChallengeDate < ActiveRecord::Migration[8.0]
  def up
    add_column :starter_challenges, :first_challenge_on, :date
    execute "UPDATE starter_challenges SET first_challenge_on = (started_at AT TIME ZONE 'UTC')::date + 1"
    change_column_null :starter_challenges, :first_challenge_on, false
  end

  def down
    remove_column :starter_challenges, :first_challenge_on
  end
end
