class NormalizeMultilingualSchema < ActiveRecord::Migration[8.0]
  def up
    # Some development/copilot databases received an earlier draft of this
    # feature. Normalize those harmless duplicate indexes so schema.rb reflects
    # exactly what a clean production migration produces.
    remove_index :courses, name: :idx_courses_published_video if index_name_exists?(:courses, :idx_courses_published_video)
    remove_index :media, name: :index_media_on_url_and_language if index_name_exists?(:media, :index_media_on_url_and_language)
    remove_index :create_song_progresses, name: :idx_create_song_progresses_unique if index_name_exists?(:create_song_progresses, :idx_create_song_progresses_unique)
    remove_index :course_translations, name: :idx_course_translations_unique if index_name_exists?(:course_translations, :idx_course_translations_unique)
    remove_index :phrase_translations, name: :idx_phrase_translations_unique if index_name_exists?(:phrase_translations, :idx_phrase_translations_unique)
    remove_index :token_translations, name: :idx_token_translations_unique_per_lang if index_name_exists?(:token_translations, :idx_token_translations_unique_per_lang)

    if index_name_exists?(:phrase_tokens, :idx_token_translations_unique) &&
        !index_name_exists?(:phrase_tokens, :idx_phrase_tokens_unique)
      rename_index :phrase_tokens, :idx_token_translations_unique, :idx_phrase_tokens_unique
    end

    change_column_null :course_translations, :name, false
    remove_column :lessons, :name_i18n if column_exists?(:lessons, :name_i18n)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "schema normalization only removes redundant draft artifacts"
  end
end
