class CreateCreateSongProgresses < ActiveRecord::Migration[8.0]
  def change
    create_table :create_song_progresses do |t|
      t.string :youtubeurl
      t.string :clip_language
      t.string :translation_language
      t.integer :step
      t.jsonb :data

      t.timestamps
    end
    add_index :create_song_progresses, [:youtubeurl, :clip_language, :translation_language], unique: true
  end
end
