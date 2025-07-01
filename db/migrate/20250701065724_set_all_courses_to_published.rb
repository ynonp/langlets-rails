class SetAllCoursesToPublished < ActiveRecord::Migration[8.0]
  def up
    # Set all existing courses to published status (1)
    execute "UPDATE courses SET status = 1 WHERE status = 0 OR status IS NULL;"
  end

  def down
    # Revert all courses back to processing status (0)
    execute "UPDATE courses SET status = 0;"
  end
end
