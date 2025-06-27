class AddUserOwnershipToCourses < ActiveRecord::Migration[8.0]
  def change
    add_reference :courses, :user, null: true, foreign_key: true, index: true
  end
end
