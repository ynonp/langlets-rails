class AddReviewBuildStateToLessons < ActiveRecord::Migration[8.0]
  def change
    add_reference :lessons, :review_language, foreign_key: { to_table: :languages }
    add_column :lessons, :review_build_status, :integer
    add_column :lessons, :review_build_error, :string
    add_index :lessons, [ :user_id, :review_language_id, :created_at ],
      name: "index_lessons_on_user_review_language_created_at",
      where: "review_language_id IS NOT NULL"
  end
end
