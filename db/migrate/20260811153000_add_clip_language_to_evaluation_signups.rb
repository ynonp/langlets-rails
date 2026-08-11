class AddClipLanguageToEvaluationSignups < ActiveRecord::Migration[8.0]
  def up
    add_column :evaluation_signups, :clip_language, :string

    execute <<~SQL.squish
      UPDATE evaluation_signups
      SET clip_language = import_requests.clip_language
      FROM import_requests
      WHERE evaluation_signups.admin_import_request_id = import_requests.id
        AND import_requests.clip_language IS NOT NULL
    SQL
  end

  def down
    remove_column :evaluation_signups, :clip_language
  end
end
