class CoursesMusthaveSlug < ActiveRecord::Migration[8.0]
  def change
    change_column_null :courses, :slug, false
  end
end
