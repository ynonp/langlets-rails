class CreatePhraseTextAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :phrase_text_assignments do |t|
      t.references :phrase, null: false, foreign_key: true
      t.references :phrase_text, null: false, foreign_key: true
      t.integer :language_role, null: false # enum :l1 or :l2
      t.boolean :primary, default: false # indicates the default text for this language

      t.timestamps
    end
    
    # Ensure only one primary text per phrase per language role
    add_index :phrase_text_assignments, [:phrase_id, :language_role, :primary], 
              unique: true, where: '"primary" = true',
              name: "idx_phrase_text_assignments_unique_primary"
  end
end
