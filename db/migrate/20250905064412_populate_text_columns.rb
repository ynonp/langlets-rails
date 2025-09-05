class PopulateTextColumns < ActiveRecord::Migration[8.0]
  def change
    # Update all phrases with placeholder text since the original multi-script data was lost
    # This is a hotfix to prevent the application from crashing due to nil values
    execute <<-SQL
      UPDATE phrases 
      SET text_l1 = '[Text content not available - please recreate course]',
          text_l2 = '[Text content not available - please recreate course]'
      WHERE text_l1 IS NULL OR text_l2 IS NULL;
    SQL
  end
end
