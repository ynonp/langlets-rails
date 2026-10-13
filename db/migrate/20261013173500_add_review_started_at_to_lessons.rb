class AddReviewStartedAtToLessons < ActiveRecord::Migration[8.0]
  def change
    add_column :lessons, :review_started_at, :datetime
  end
end
