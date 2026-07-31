class AllowLanguageDetectionInCreateSongProgresses < ActiveRecord::Migration[8.0]
  def change
    change_column_null :create_song_progresses, :clip_language, true
    remove_index :create_song_progresses, name: :idx_create_song_progresses_video_language
    add_index :create_song_progresses, [ :youtubeurl, :clip_language ],
              unique: true,
              where: "clip_language IS NOT NULL",
              name: :idx_create_song_progresses_video_language
  end
end
