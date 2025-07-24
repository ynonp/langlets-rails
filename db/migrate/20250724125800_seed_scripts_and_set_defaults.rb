class SeedScriptsAndSetDefaults < ActiveRecord::Migration[8.0]
  def up
    # Create common scripts
    latin = Script.create!(code: 'Latn', name: 'Latin')
    hebrew = Script.create!(code: 'Hebr', name: 'Hebrew')
    cyrillic = Script.create!(code: 'Cyrl', name: 'Cyrillic')
    arabic = Script.create!(code: 'Arab', name: 'Arabic')
    
    # Map common language ISO codes to their default scripts
    script_mappings = {
      'en' => latin,    # English
      'es' => latin,    # Spanish
      'fr' => latin,    # French
      'de' => latin,    # German
      'it' => latin,    # Italian
      'pt' => latin,    # Portuguese
      'nl' => latin,    # Dutch
      'sv' => latin,    # Swedish
      'no' => latin,    # Norwegian
      'da' => latin,    # Danish
      'fi' => latin,    # Finnish
      'he' => hebrew,   # Hebrew
      'ar' => arabic,   # Arabic
      'ru' => cyrillic, # Russian
      'bg' => cyrillic, # Bulgarian
      'sr' => cyrillic, # Serbian
      'mk' => cyrillic, # Macedonian
      'uk' => cyrillic, # Ukrainian
      'be' => cyrillic  # Belarusian
    }
    
    # Update existing languages with default scripts
    Language.find_each do |language|
      next unless language.iso_name.present?
      
      default_script = script_mappings[language.iso_name] || latin # Default to Latin if not found
      language.update!(default_script: default_script)
    end
  end

  def down
    # Remove script assignments
    Language.update_all(default_script_id: nil)
    
    # Remove scripts
    Script.destroy_all
  end
end
