class CreateLanguages < ActiveRecord::Migration[8.0]
  def change
    create_table :languages do |t|
      t.string :iso_name
      t.string :english_name
      t.string :native_name

      t.timestamps
    end

    add_index :languages, :iso_name, unique: true
  end
end
