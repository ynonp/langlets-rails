class CreateScripts < ActiveRecord::Migration[8.0]
  def change
    create_table :scripts do |t|
      t.string :name, null: false # "latin", "hebrew", "arabic", "cyrillic"
      t.string :iso_code # "Latn", "Hebr", "Arab", "Cyrl" (ISO 15924)
      t.boolean :rtl, default: false

      t.timestamps
    end
    add_index :scripts, :name, unique: true
  end
end
