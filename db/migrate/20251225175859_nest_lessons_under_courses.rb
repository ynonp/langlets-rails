class NestLessonsUnderCourses < ActiveRecord::Migration[8.0]
  def change
    # Add foreign key constraint from lessons to courses
    add_foreign_key :lessons, :courses

    # Remove the global unique index on slug
    remove_index :lessons, :slug, if_exists: true

    # Add composite unique index on [course_id, slug] for lessons with course_id
    add_index :lessons, [:course_id, :slug], 
      unique: true, 
      where: "course_id IS NOT NULL",
      name: "index_lessons_on_course_id_and_slug"
  end
end

