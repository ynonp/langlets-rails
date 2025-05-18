class CreateActivityTokenTranslations < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_token_translations do |t|
      t.references :activity, null: false, foreign_key: true
      t.references :token_translation, null: false, foreign_key: true

      t.timestamps
    end
    add_index :activity_token_translations, [:activity_id, :token_translation_id]
  end
end
