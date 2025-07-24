class CreateScripts < ActiveRecord::Migration[8.0]
  def change
    create_table :scripts do |t|
      t.string :code, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :scripts, :code, unique: true
  end
end
