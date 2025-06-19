class CreateLearningPaths < ActiveRecord::Migration[8.0]
  def change
    create_table :learning_paths do |t|
      t.string :name
      t.text :description
      t.integer :difficulty_level
      t.boolean :published

      t.timestamps
    end
  end
end
