class CreateEvaluationSignups < ActiveRecord::Migration[8.0]
  def change
    create_table :evaluation_signups do |t|
      t.uuid :token, null: false, default: -> { "gen_random_uuid()" }
      t.references :user, null: true, foreign_key: true
      t.references :admin_import_request, null: false, foreign_key: { to_table: :import_requests }
      t.references :initial_course, null: false, foreign_key: { to_table: :courses }
      t.references :course, null: false, foreign_key: true
      t.string :video_url, null: false
      t.string :video_id, null: false
      t.string :provider, null: false
      t.string :title, null: false
      t.string :author_name
      t.string :thumbnail_url
      t.string :translation_language, null: false
      t.datetime :claimed_at
      t.datetime :consumed_at
      t.timestamps
    end

    add_index :evaluation_signups, :token, unique: true
    add_index :evaluation_signups, [ :user_id, :consumed_at ]
  end
end
