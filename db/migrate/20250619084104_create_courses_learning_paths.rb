class CreateCoursesLearningPaths < ActiveRecord::Migration[8.0]
  def change
    create_table :courses_learning_paths do |t|
      t.references :course, null: false, foreign_key: true
      t.references :learning_path, null: false, foreign_key: true
      t.integer :order

      t.timestamps
    end
  end
end
