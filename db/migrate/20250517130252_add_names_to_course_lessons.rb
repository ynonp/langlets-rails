class AddNamesToCourseLessons < ActiveRecord::Migration[8.0]
  def change
    add_column :course_lessons, :name, :string
  end
end
