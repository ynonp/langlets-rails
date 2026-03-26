class MakeReviewLessonsNullable < ActiveRecord::Migration[8.0]
  def up
    # Allow review lessons without a course
    remove_foreign_key :lessons, :courses
    change_column_null :lessons, :course_id, true
    add_foreign_key :lessons, :courses, on_delete: :cascade

    # Allow review lessons without a medium (no video)
    remove_foreign_key :lessons, :media
    change_column_null :lessons, :medium_id, true
    add_foreign_key :lessons, :media

    # Drop the old unique index scoped to course_id (doesn't work cleanly with NULLs)
    remove_index :lessons, name: "index_lessons_on_course_id_and_slug", if_exists: true
    # Add a partial unique index for course-based lessons
    add_index :lessons, [:course_id, :slug], unique: true,
              name: "index_lessons_on_course_id_and_slug",
              where: "course_id IS NOT NULL"
  end

  def down
    remove_index :lessons, name: "index_lessons_on_course_id_and_slug", if_exists: true
    add_index :lessons, [:course_id, :slug], unique: true, name: "index_lessons_on_course_id_and_slug"

    change_column_null :lessons, :course_id, false
    change_column_null :lessons, :medium_id, false
  end
end
