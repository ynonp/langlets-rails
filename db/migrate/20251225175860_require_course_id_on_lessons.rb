class RequireCourseIdOnLessons < ActiveRecord::Migration[8.0]
  def up
    # Remove the old unique index on slug alone (if it exists)
    remove_index :lessons, :slug, if_exists: true
    
    # Remove the partial composite index
    remove_index :lessons, name: "index_lessons_on_course_id_and_slug", if_exists: true
    
    # Add NOT NULL constraint to course_id
    change_column_null :lessons, :course_id, false
    
    # Add new composite unique index without WHERE clause
    add_index :lessons, [:course_id, :slug], unique: true, name: "index_lessons_on_course_id_and_slug"
  end

  def down
    # Remove the composite unique index
    remove_index :lessons, name: "index_lessons_on_course_id_and_slug", if_exists: true
    
    # Restore nullable course_id
    change_column_null :lessons, :course_id, true
    
    # Restore partial composite index with WHERE clause
    add_index :lessons, [:course_id, :slug], 
      unique: true, 
      where: "course_id IS NOT NULL",
      name: "index_lessons_on_course_id_and_slug"
    
    # Restore old unique index on slug alone
    add_index :lessons, :slug, unique: true
  end
end
