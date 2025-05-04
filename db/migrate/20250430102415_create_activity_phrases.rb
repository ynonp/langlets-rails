class CreateActivityPhrases < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_phrases do |t|
      t.references :activity, null: false, foreign_key: true
      t.references :phrase, null: false, foreign_key: true

      t.timestamps
    end
  end
end
