class CreateSimilarSounds < ActiveRecord::Migration[8.0]
  def change
    create_table :similar_sounds do |t|
      t.integer :start_word_index, null: false
      t.integer :end_word_index, null: false
      t.string :replacement_text, null: false
      t.references :phrase, null: false, foreign_key: true

      t.timestamps
    end
  end
end
