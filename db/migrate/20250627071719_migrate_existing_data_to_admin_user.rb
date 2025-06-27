class MigrateExistingDataToAdminUser < ActiveRecord::Migration[8.0]
  def up
    # Create admin user if it doesn't exist
    admin_email = 'ynon@hey.com'
    
    # Check if admin user exists
    admin_user_exists = execute("SELECT COUNT(*) FROM users WHERE email = '#{admin_email}'").first['count'].to_i > 0
    
    unless admin_user_exists
      # Create admin user - password will be '10203040'
      # Using BCrypt to generate the hash for password '10203040'
      require 'bcrypt'
      encrypted_password = BCrypt::Password.create('10203040')
      
      execute <<-SQL
        INSERT INTO users (email, encrypted_password, confirmed_at, created_at, updated_at)
        VALUES (
          '#{admin_email}',
          '#{encrypted_password}',
          NOW(),
          NOW(),
          NOW()
        )
      SQL
    end
    
    # Get admin user ID
    admin_user_id = execute("SELECT id FROM users WHERE email = '#{admin_email}' LIMIT 1").first['id']
    
    # Update courses to belong to admin user
    execute <<-SQL
      UPDATE courses 
      SET user_id = #{admin_user_id}
      WHERE user_id IS NULL
    SQL
    
    # Update lessons to belong to admin user
    execute <<-SQL
      UPDATE lessons 
      SET user_id = #{admin_user_id}
      WHERE user_id IS NULL
    SQL
    
    # Update activities to belong to admin user
    execute <<-SQL
      UPDATE activities 
      SET user_id = #{admin_user_id}
      WHERE user_id IS NULL
    SQL
  end

  def down
    # Remove user_id from all records (set to NULL)
    execute "UPDATE courses SET user_id = NULL"
    execute "UPDATE lessons SET user_id = NULL"
    execute "UPDATE activities SET user_id = NULL"
  end
end
