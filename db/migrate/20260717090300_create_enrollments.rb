class CreateEnrollments < ActiveRecord::Migration[8.0]
  # "This course is on my Home." There was no such concept: a course a user
  # started was inferred from lesson_users, and a course they created from
  # courses.user_id. Neither covers the Library's "+ Learn this", which puts a
  # course on Home *before* any lesson is completed, so it needs a record of its
  # own.
  def up
    create_table :enrollments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true

      # imported: they spent a credit on it. library: added from the catalog.
      # learning_path: came in via a curated path.
      t.integer :source, null: false, default: 0

      # Drives Home's "Keep it going" ordering. Maintained by LessonUser.
      t.datetime :last_practiced_at

      t.timestamps
    end

    add_index :enrollments, [ :user_id, :course_id ], unique: true
    add_index :enrollments, [ :user_id, :last_practiced_at ]

    backfill!
  end

  def down
    drop_table :enrollments
  end

  private

  # source values are Enrollment.sources: imported = 0, library = 1.
  def backfill!
    # Creators first, so that someone who both created a course and practised it
    # is recorded as having imported it rather than found it in the Library.
    execute <<~SQL.squish
      INSERT INTO enrollments (user_id, course_id, source, created_at, updated_at)
      SELECT c.user_id, c.id, 0, now(), now()
        FROM courses c
      ON CONFLICT (user_id, course_id) DO NOTHING
    SQL

    execute <<~SQL.squish
      INSERT INTO enrollments (user_id, course_id, source, created_at, updated_at)
      SELECT lu.user_id, l.course_id, 1, now(), now()
        FROM lesson_users lu
        JOIN lessons l ON l.id = lu.lesson_id
       GROUP BY lu.user_id, l.course_id
      ON CONFLICT (user_id, course_id) DO NOTHING
    SQL

    # Seed last_practiced_at from existing progress, whatever the source.
    execute <<~SQL.squish
      UPDATE enrollments e
         SET last_practiced_at = sub.practised_at
        FROM (
          SELECT lu.user_id, l.course_id, MAX(lu.created_at) AS practised_at
            FROM lesson_users lu
            JOIN lessons l ON l.id = lu.lesson_id
           GROUP BY lu.user_id, l.course_id
        ) sub
       WHERE e.user_id = sub.user_id
         AND e.course_id = sub.course_id
    SQL
  end
end
