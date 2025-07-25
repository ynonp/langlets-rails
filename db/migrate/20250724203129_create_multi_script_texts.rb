class CreateMultiScriptTexts < ActiveRecord::Migration[8.0]
  def change
    create_table :multi_script_texts do |t|
      t.timestamps
    end
  end
end
