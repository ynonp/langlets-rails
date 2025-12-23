class AddShowFullCoursePlayerToCourses < ActiveRecord::Migration[8.0]
  def change
    add_column :courses, :show_full_course_player, :boolean, default: true, null: false
  end
end
