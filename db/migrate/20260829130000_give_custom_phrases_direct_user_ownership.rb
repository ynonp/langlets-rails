class GiveCustomPhrasesDirectUserOwnership < ActiveRecord::Migration[8.0]
  CUSTOM_MEDIUM_PATTERN = "^langlets://custom-vocabulary/[0-9]+$"

  def up
    add_reference :phrases, :user, null: true, foreign_key: true
    change_column_null :phrases, :medium_id, true

    execute <<~SQL
      UPDATE phrases
      SET user_id = users.id,
          medium_id = NULL
      FROM media, users
      WHERE phrases.medium_id = media.id
        AND media.url ~ '#{CUSTOM_MEDIUM_PATTERN}'
        AND users.id = substring(media.url from '[0-9]+$')::bigint
    SQL

    unmigrated = select_value(<<~SQL).to_i
      SELECT COUNT(*)
      FROM phrases
      INNER JOIN media ON media.id = phrases.medium_id
      WHERE media.url LIKE 'langlets://custom-vocabulary/%'
    SQL
    raise "Could not resolve the owner of #{unmigrated} custom vocabulary phrases" if unmigrated.positive?

    custom_lessons = select_value(<<~SQL).to_i
      SELECT COUNT(*)
      FROM lessons
      INNER JOIN media ON media.id = lessons.medium_id
      WHERE media.url LIKE 'langlets://custom-vocabulary/%'
    SQL
    raise "Custom vocabulary media unexpectedly belong to #{custom_lessons} lessons" if custom_lessons.positive?

    add_check_constraint :phrases,
      "(medium_id IS NOT NULL) <> (user_id IS NOT NULL)",
      name: "phrases_exactly_one_source"

    execute <<~SQL
      DELETE FROM media
      WHERE url LIKE 'langlets://custom-vocabulary/%'
    SQL
  end

  def down
    remove_check_constraint :phrases, name: "phrases_exactly_one_source"

    execute <<~SQL
      INSERT INTO media (url, language_id, created_at, updated_at)
      SELECT DISTINCT
        'langlets://custom-vocabulary/' || phrases.user_id,
        phrases.l1_id,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM phrases
      WHERE phrases.user_id IS NOT NULL
      ON CONFLICT (url, language_id) DO NOTHING
    SQL

    execute <<~SQL
      UPDATE phrases
      SET medium_id = media.id,
          user_id = NULL
      FROM media
      WHERE phrases.user_id IS NOT NULL
        AND media.url = 'langlets://custom-vocabulary/' || phrases.user_id
        AND media.language_id = phrases.l1_id
    SQL

    change_column_null :phrases, :medium_id, false
    remove_reference :phrases, :user, foreign_key: true
  end
end
