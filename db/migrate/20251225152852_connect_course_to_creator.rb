class ConnectCourseToCreator < ActiveRecord::Migration[8.0]
  # Reconciles db/schema.rb with db/migrate: courses.create_song_progress_id has
  # been in the schema since 3064ce4 with no migration behind it, so migrating a
  # fresh database from zero produced a schema the app couldn't run against.
  #
  # Guarded because databases built with db:schema:load already have the column
  # but not this version, and would otherwise fail on the next deploy.
  def change
    return if column_exists?(:courses, :create_song_progress_id)

    add_reference :courses, :create_song_progress
  end
end
