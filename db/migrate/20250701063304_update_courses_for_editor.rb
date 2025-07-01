class UpdateCoursesForEditor < ActiveRecord::Migration[8.0]
  def change
    # Add status enum field (0: processing, 1: published)
    add_column :courses, :status, :integer, default: 0, null: false
    
    # Add unique indexes for name and slug to prevent duplicates
    add_index :courses, :name, unique: true
    add_index :courses, :slug, unique: true
  end
end
