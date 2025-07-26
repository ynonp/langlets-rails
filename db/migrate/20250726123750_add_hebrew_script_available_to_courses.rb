class AddHebrewScriptAvailableToCourses < ActiveRecord::Migration[8.0]
  def change
    add_column :courses, :hebrew_script_available, :boolean, default: false, null: false
  end
end
