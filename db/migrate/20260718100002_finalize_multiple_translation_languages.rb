class FinalizeMultipleTranslationLanguages < ActiveRecord::Migration[8.0]
  def up
    change_column_null :phrase_translations, :text, false
    change_column_null :token_translations, :translation, false
    change_column_null :phrase_token_users, :language_id, false

    remove_column :phrase_tokens, :translation if column_exists?(:phrase_tokens, :translation)
    remove_column :phrase_tokens, :l2_start_index if column_exists?(:phrase_tokens, :l2_start_index)
    remove_column :phrase_tokens, :l2_end_index if column_exists?(:phrase_tokens, :l2_end_index)
    remove_column :phrases, :l2_id if column_exists?(:phrases, :l2_id)
    remove_column :phrases, :text_l2 if column_exists?(:phrases, :text_l2)

    remove_index :media, name: :index_media_on_url_and_language_pair if index_name_exists?(:media, :index_media_on_url_and_language_pair)
    remove_column :media, :translation_language_id if column_exists?(:media, :translation_language_id)
    add_index :media, [ :url, :language_id ], unique: true, if_not_exists: true

    remove_index :courses, name: :idx_courses_published_video_pair if index_name_exists?(:courses, :idx_courses_published_video_pair)
    remove_column :courses, :translation_language_id if column_exists?(:courses, :translation_language_id)
    add_index :courses, [ :youtube_video_id, :language_id ], unique: true,
              where: "status = 1", name: :idx_courses_published_video_language, if_not_exists: true

    remove_index :create_song_progresses, name: :idx_on_youtubeurl_clip_language_translation_languag_d876aa04dc if index_name_exists?(:create_song_progresses, :idx_on_youtubeurl_clip_language_translation_languag_d876aa04dc)
    add_index :create_song_progresses, [ :youtubeurl, :clip_language ], unique: true,
              name: :idx_create_song_progresses_video_language, if_not_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "legacy multilingual columns were removed"
  end
end
