class RemoveReviewLessonBuilds < ActiveRecord::Migration[8.0]
  def change
    drop_table :review_lesson_builds
    remove_column :lessons, :review_build_error, :string
  end
end
