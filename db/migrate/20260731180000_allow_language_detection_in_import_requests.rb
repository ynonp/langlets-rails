class AllowLanguageDetectionInImportRequests < ActiveRecord::Migration[8.0]
  def change
    change_column_null :import_requests, :clip_language, true

    add_index :import_requests,
              [ :user_id, :youtube_video_id, :translation_language ],
              unique: true,
              where: "status = 5 AND clip_language IS NULL",
              name: "idx_import_requests_detecting_dedupe"
  end
end
