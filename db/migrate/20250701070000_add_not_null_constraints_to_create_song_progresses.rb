class AddNotNullConstraintsToCreateSongProgresses < ActiveRecord::Migration[8.0]
  def change
    change_column_null :create_song_progresses, :youtubeurl, false
    change_column_null :create_song_progresses, :clip_language, false
    change_column_null :create_song_progresses, :translation_language, false
  end
end
