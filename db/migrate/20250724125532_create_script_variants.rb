class CreateScriptVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :script_variants do |t|
      t.references :multi_script_text, null: false, foreign_key: true
      t.references :script, null: false, foreign_key: true
      t.text :content, null: false

      t.timestamps
    end

    add_index :script_variants, [:multi_script_text_id, :script_id], unique: true, name: 'index_script_variants_on_text_and_script'
  end
end
