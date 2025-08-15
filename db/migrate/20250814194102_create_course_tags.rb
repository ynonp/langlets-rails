class CreateCourseTags < ActiveRecord::Migration[8.0]
  def change
    create_table :course_tags do |t|
      t.references :course, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :course_tags, [:course_id, :tag_id], unique: true
  end
end
