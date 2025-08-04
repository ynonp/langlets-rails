class AddLyricsToCsp < ActiveRecord::Migration[8.0]
  def change
    add_column :create_song_progresses, :lyrics, :text
  end
end
