class CreateScriptsAndPhraseTexts < ActiveRecord::Migration[8.0]
  def change
    # Table 1: Scripts - Reference table for writing systems
    create_table :scripts do |t|
      t.string :name, null: false # "latin", "hebrew", "arabic", "cyrillic"
      t.string :iso_code # "Latn", "Hebr", "Arab", "Cyrl" (ISO 15924)
      t.boolean :rtl, default: false
      t.timestamps
    end

    # Table 2: Phrase Texts - Stores actual text content
    create_table :phrase_texts do |t|
      t.text :content, null: false
      t.references :script, null: false, foreign_key: true
      t.timestamps
    end

    # Table 3: Join table - Links phrases to their text variants
    create_table :phrase_text_assignments do |t|
      t.references :phrase, null: false, foreign_key: true
      t.references :phrase_text, null: false, foreign_key: true
      t.integer :language_role, null: false # enum :l1 or :l2
      t.boolean :primary, default: false # indicates the default text for this language
      t.timestamps
    end

    # Add indexes
    add_index :phrase_text_assignments, [:phrase_id, :language_role, :primary], 
              unique: true, where: '"primary" = true',
              name: "idx_phrase_text_assignments_unique_primary"
    add_index :scripts, :name, unique: true
  end
end
