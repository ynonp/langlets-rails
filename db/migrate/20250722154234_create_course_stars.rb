class CreateCourseStars < ActiveRecord::Migration[8.0]
  def change
    create_table :course_stars do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true

      t.timestamps
    end
    
    # Add unique constraint to prevent duplicate stars from same user
    add_index :course_stars, [:user_id, :course_id], unique: true
  end
end
