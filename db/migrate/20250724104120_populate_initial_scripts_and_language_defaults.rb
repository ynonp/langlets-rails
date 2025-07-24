class PopulateInitialScriptsAndLanguageDefaults < ActiveRecord::Migration[8.0]
  def up
    # Create initial scripts using execute to avoid model dependencies
    execute <<-SQL
      INSERT INTO scripts (name, iso_code, rtl, created_at, updated_at) VALUES
      ('latin', 'Latn', false, NOW(), NOW()),
      ('hebrew', 'Hebr', true, NOW(), NOW()),
      ('arabic', 'Arab', true, NOW(), NOW()),
      ('cyrillic', 'Cyrl', false, NOW(), NOW())
    SQL
    
    # Get script IDs
    latin_script_id = execute("SELECT id FROM scripts WHERE name = 'latin'").first['id']
    hebrew_script_id = execute("SELECT id FROM scripts WHERE name = 'hebrew'").first['id']
    arabic_script_id = execute("SELECT id FROM scripts WHERE name = 'arabic'").first['id']
    cyrillic_script_id = execute("SELECT id FROM scripts WHERE name = 'cyrillic'").first['id']
    
    # Update existing languages with default scripts
    execute "UPDATE languages SET default_script_id = #{latin_script_id} WHERE iso_name IN ('en', 'es', 'fr')"
    execute "UPDATE languages SET default_script_id = #{hebrew_script_id} WHERE iso_name = 'he'"
    execute "UPDATE languages SET default_script_id = #{arabic_script_id} WHERE iso_name = 'ar'"
    execute "UPDATE languages SET default_script_id = #{cyrillic_script_id} WHERE iso_name = 'ru'"
    
    # Set all remaining languages without default scripts to latin
    execute "UPDATE languages SET default_script_id = #{latin_script_id} WHERE default_script_id IS NULL"
  end
  
  def down
    # Reset default scripts to nil
    execute "UPDATE languages SET default_script_id = NULL"
    
    # Remove all scripts
    execute "DELETE FROM scripts"
  end
end
