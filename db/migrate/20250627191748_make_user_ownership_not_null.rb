class MakeUserOwnershipNotNull < ActiveRecord::Migration[8.0]
  def up
    change_column_null :courses, :user_id, false
    change_column_null :lessons, :user_id, false
    change_column_null :activities, :user_id, false
  end

  def down
    change_column_null :courses, :user_id, true
    change_column_null :lessons, :user_id, true
    change_column_null :activities, :user_id, true
  end
end
