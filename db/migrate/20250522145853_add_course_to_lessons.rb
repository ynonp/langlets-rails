class AddCourseToLessons < ActiveRecord::Migration[8.0]
  def change
    add_reference :lessons, :course
    add_column :lessons, :order, :integer, default: 0
    add_column :lessons, :name, :string
    drop_table :course_lessons
  end
end
