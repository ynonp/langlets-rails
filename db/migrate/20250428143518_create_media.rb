class CreateMedia < ActiveRecord::Migration[8.0]
  def change
    create_table :media do |t|
      t.string :url

      t.timestamps
    end
    add_index :media, :url, unique: true
  end
end
