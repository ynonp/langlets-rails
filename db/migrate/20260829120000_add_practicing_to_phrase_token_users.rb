class AddPracticingToPhraseTokenUsers < ActiveRecord::Migration[8.0]
  # "Stop practising" in the Vocabulary tab. A paused word stays in the user's
  # vocabulary — it is still listed, searchable and editable — but leaves every
  # review lesson. Deleting is the separate, destructive action.
  def change
    add_column :phrase_token_users, :practicing, :boolean, default: true, null: false
    add_index :phrase_token_users, [ :user_id, :practicing ]
  end
end
