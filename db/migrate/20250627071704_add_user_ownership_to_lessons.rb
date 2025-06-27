class AddUserOwnershipToLessons < ActiveRecord::Migration[8.0]
  def change
    add_reference :lessons, :user, null: true, foreign_key: true, index: true
  end
end
