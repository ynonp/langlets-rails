class AddDedupeKeysToCourses < ActiveRecord::Migration[8.0]
  # The Library shows one course per video per language pair, and a duplicate
  # import is supposed to hand back the existing course without charging. Neither
  # is expressible today: courses.main_media_url is free text, so youtu.be/X and
  # watch?v=X&t=9 look like different videos, and nothing records which language a
  # course translates *into* (courses.language_id is the clip language).
  #
  # The partial unique index is the Library's canonical-course invariant. Keeping
  # it in the database rather than in application code means a race between two
  # importers can't produce two published courses for the same pair.
  def up
    add_column :courses, :youtube_video_id, :string
    add_reference :courses, :translation_language, foreign_key: { to_table: :languages }
    add_index :courses, :youtube_video_id

    backfill_video_ids!
    backfill_translation_languages!

    # status = 1 is Course.statuses[:published]. Scoped to published so that
    # failed and in-flight imports of the same video don't block each other.
    add_index :courses,
              [ :youtube_video_id, :language_id, :translation_language_id ],
              unique: true,
              where: "status = 1",
              name: "idx_courses_published_video_pair"
  end

  def down
    remove_index :courses, name: "idx_courses_published_video_pair"
    remove_reference :courses, :translation_language
    remove_column :courses, :youtube_video_id
  end

  private

  # Ruby rather than SQL because the URL shapes need Youtube::Url's regex, and
  # this is a few dozen rows.
  def backfill_video_ids!
    Course.reset_column_information

    Course.where(youtube_video_id: nil).find_each do |course|
      video_id = Youtube::Url.video_id(course.main_media_url)
      next if video_id.blank?

      course.update_columns(youtube_video_id: video_id)
    end
  end

  # A course's translation language is the one its medium was built for. All of a
  # course's lessons share a medium, so any lesson answers it.
  def backfill_translation_languages!
    execute <<~SQL.squish
      UPDATE courses c
         SET translation_language_id = sub.translation_language_id
        FROM (
          SELECT DISTINCT ON (l.course_id)
                 l.course_id, m.translation_language_id
            FROM lessons l
            JOIN media m ON m.id = l.medium_id
           WHERE m.translation_language_id IS NOT NULL
           ORDER BY l.course_id, l.id
        ) sub
       WHERE c.id = sub.course_id
         AND c.translation_language_id IS NULL
    SQL
  end
end
