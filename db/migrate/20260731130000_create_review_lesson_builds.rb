class CreateReviewLessonBuilds < ActiveRecord::Migration[8.0]
  def change
    create_table :review_lesson_builds do |t|
      t.references :user, null: false, foreign_key: true
      t.references :language, foreign_key: true
      t.references :lesson, foreign_key: true
      t.string :request_id, null: false
      t.integer :status, null: false, default: 0
      t.string :error

      t.timestamps
    end

    add_index :review_lesson_builds, :request_id, unique: true
    add_index :review_lesson_builds, [ :user_id, :created_at ]
  end
end
