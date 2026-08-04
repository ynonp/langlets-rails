# CreateSongProgress no longer has a language of its own: every caller that
# needs one (CreateCourseJob, ImportCourseJob, AddCourseTranslationJob,
# CourseBuilder::BuildSong#call) now receives it explicitly, and the record's
# content lives under data["translations"][iso] for however many languages it
# holds. All rows are already in that format (rake create_song_progress:convert_records
# was run before this migration), so there is nothing left to backfill.
class RemoveTranslationLanguageFromCreateSongProgresses < ActiveRecord::Migration[8.0]
  def change
    remove_column :create_song_progresses, :translation_language, :string, null: false
  end
end
