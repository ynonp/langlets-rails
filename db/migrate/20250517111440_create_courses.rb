class CreateCourses < ActiveRecord::Migration[8.0]
  def change
    create_table :courses do |t|
      t.string :name
      t.string :slug
      t.string :main_media_url

      t.timestamps
    end
  end
end
