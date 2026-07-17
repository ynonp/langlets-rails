class RenameLearningPathsToPlaylists < ActiveRecord::Migration[8.0]
  def change
    rename_table :learning_paths, :playlists
    rename_table :courses_learning_paths, :courses_playlists
    rename_column :courses_playlists, :learning_path_id, :playlist_id

    # nil user = system playlist, curated by admins and visible to everyone.
    add_reference :playlists, :user, foreign_key: true, null: true
  end
end
