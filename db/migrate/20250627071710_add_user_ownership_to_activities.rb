class AddUserOwnershipToActivities < ActiveRecord::Migration[8.0]
  def change
    add_reference :activities, :user, null: true, foreign_key: true, index: true
  end
end
