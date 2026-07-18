class BackfillMultipleTranslationLanguages < ActiveRecord::Migration[8.0]
  def up
    if column_exists?(:phrases, :l2_id)
      execute <<~SQL
      INSERT INTO phrase_translations (phrase_id, language_id, text, created_at, updated_at)
      SELECT id, l2_id, text_l2, created_at, updated_at
      FROM phrases
      WHERE l2_id IS NOT NULL AND text_l2 IS NOT NULL
      ON CONFLICT (phrase_id, language_id) DO NOTHING
      SQL
    end

    # Also covers databases that already performed the token split before the
    # save-time language column was introduced. Existing data has one L2 row per
    # span, so that row is the unambiguous source language.
    execute <<~SQL
      UPDATE phrase_token_users ptu
      SET language_id = tt.language_id
      FROM token_translations tt
      WHERE ptu.phrase_token_id = tt.phrase_token_id
        AND ptu.language_id IS NULL
    SQL

    if column_exists?(:phrase_tokens, :translation)
      execute <<~SQL
      INSERT INTO token_translations
        (phrase_token_id, language_id, translation, l2_start_index, l2_end_index, created_at, updated_at)
      SELECT pt.id, p.l2_id, pt.translation, pt.l2_start_index, pt.l2_end_index, pt.created_at, pt.updated_at
      FROM phrase_tokens pt
      JOIN phrases p ON p.id = pt.phrase_id
      WHERE p.l2_id IS NOT NULL AND pt.translation IS NOT NULL
      ON CONFLICT (phrase_token_id, language_id) DO NOTHING
      SQL
    end

    if column_exists?(:phrases, :l2_id)
      execute <<~SQL
      UPDATE phrase_token_users ptu
      SET language_id = p.l2_id
      FROM phrase_tokens pt
      JOIN phrases p ON p.id = pt.phrase_id
      WHERE ptu.phrase_token_id = pt.id AND ptu.language_id IS NULL
      SQL
    end

    if column_exists?(:courses, :translation_language_id)
      execute <<~SQL
      INSERT INTO course_translations (course_id, language_id, status, name, created_at, updated_at)
      SELECT id, translation_language_id,
             CASE WHEN status = 1 THEN 1 WHEN status = 3 THEN 2 ELSE 0 END,
             name, created_at, updated_at
      FROM courses
      WHERE translation_language_id IS NOT NULL AND name IS NOT NULL
      ON CONFLICT (course_id, language_id) DO NOTHING
      SQL

      execute <<~SQL
      INSERT INTO lesson_translations (lesson_id, language_id, name, created_at, updated_at)
      SELECT lessons.id, courses.translation_language_id, lessons.name, lessons.created_at, lessons.updated_at
      FROM lessons
      JOIN courses ON courses.id = lessons.course_id
      WHERE courses.translation_language_id IS NOT NULL AND lessons.name IS NOT NULL
      ON CONFLICT (lesson_id, language_id) DO NOTHING
      SQL
    end

    execute <<~SQL
      UPDATE active_storage_attachments
      SET record_type = 'PhraseToken'
      WHERE record_type = 'TokenTranslation'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "backfilled multilingual rows may have changed"
  end
end
