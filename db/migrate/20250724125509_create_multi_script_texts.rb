class CreateMultiScriptTexts < ActiveRecord::Migration[8.0]
  def change
    create_table :multi_script_texts do |t|
      t.references :language, null: false, foreign_key: true

      t.timestamps
    end
  end
end
