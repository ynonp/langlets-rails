class CreateCourseLikes < ActiveRecord::Migration[8.0]
  def change
    create_table :course_likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :course_likes, [:user_id, :course_id], unique: true
  end
end
