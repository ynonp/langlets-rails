class CreateTokenTranslations < ActiveRecord::Migration[8.0]
  def change
    create_table :token_translations do |t|
      t.references :phrase, null: false, foreign_key: true
      t.integer :start_index
      t.integer :end_index
      t.string :translation
      t.string :questions, array: true

      t.timestamps
    end
    add_index :token_translations, [:phrase_id, :start_index, :end_index], unique: true
  end
end
