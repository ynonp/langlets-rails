class CreatePhraseTexts < ActiveRecord::Migration[8.0]
  def change
    create_table :phrase_texts do |t|
      t.text :content, null: false
      t.references :script, null: false, foreign_key: true

      t.timestamps
    end
  end
end
