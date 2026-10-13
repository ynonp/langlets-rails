class AddVocabularyReviewSchedule < ActiveRecord::Migration[8.0]
  def change
    add_column :phrase_token_users, :familiarity, :integer, default: 0, null: false
    add_column :phrase_token_users, :next_review_at, :datetime
    add_column :phrase_token_users, :last_reviewed_at, :datetime
    add_reference :phrase_token_users, :last_review_lesson, foreign_key: { to_table: :lessons, on_delete: :nullify }
    add_index :phrase_token_users, [ :user_id, :practicing, :next_review_at ], name: "index_saved_words_on_review_due"
    add_check_constraint :phrase_token_users, "familiarity BETWEEN 0 AND 5", name: "saved_words_familiarity_range"
  end
end
