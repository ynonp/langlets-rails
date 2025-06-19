class AssignLanguagesToCourses < ActiveRecord::Migration[8.0]
  def up
    # Update courses with language_id based on the first phrase's l1 language
    # This translates to: Course.first.lessons.first.medium.phrases.first.l1
    execute <<-SQL
      UPDATE courses 
      SET language_id = (
        SELECT phrases.l1_id
        FROM lessons 
        JOIN media ON lessons.medium_id = media.id
        JOIN phrases ON phrases.medium_id = media.id
        WHERE lessons.course_id = courses.id
        ORDER BY lessons."order" ASC, phrases.timestamp ASC
        LIMIT 1
      )
      WHERE language_id IS NULL
      AND EXISTS (
        SELECT 1 
        FROM lessons 
        JOIN media ON lessons.medium_id = media.id
        JOIN phrases ON phrases.medium_id = media.id
        WHERE lessons.course_id = courses.id
      );
    SQL
  end

  def down
    # Optionally remove language assignments if needed
    execute <<-SQL
      UPDATE courses SET language_id = NULL;
    SQL
  end
end
