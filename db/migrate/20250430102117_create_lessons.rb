class CreateLessons < ActiveRecord::Migration[8.0]
  def change
    create_table :lessons do |t|
      t.string :slug
      t.references :medium, null: false, foreign_key: true
      t.string :start_timestamp
      t.string :end_timestamp

      t.timestamps
    end
    add_index :lessons, :slug, unique: true
  end
end
