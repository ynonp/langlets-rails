# One Dictionary-tab lookup: what the learner typed, the AI card generated for
# it, and (once saved) the vocabulary token it became. The card text, the
# illustration and the pronunciation are produced by separate jobs, each with
# its own status, so the card can render as soon as the text exists.
class CreateDictionaryLookups < ActiveRecord::Migration[8.0]
  def change
    create_table :dictionary_lookups do |t|
      t.references :user, null: false, foreign_key: true
      t.string :query, null: false
      t.references :target_language, null: false, foreign_key: { to_table: :languages }
      t.references :native_language, null: false, foreign_key: { to_table: :languages }
      # What the model said the query was written in (an ISO code from the
      # supported list, or "other"). Display only; direction is stored below.
      t.string :detected_language
      # "to_native" when the query was in the target language, "to_target"
      # otherwise. Decided from the detection, never asked of the user.
      t.string :direction
      t.integer :status, null: false, default: 0
      t.integer :illustration_status, null: false, default: 0
      t.string :headword
      t.string :transliteration
      t.string :part_of_speech
      t.string :grammar_notes, array: true, null: false, default: []
      t.string :translation
      t.text :explanation
      t.jsonb :examples, null: false, default: []
      t.text :illustration_prompt
      t.string :failure_reason
      t.references :phrase_token, foreign_key: { on_delete: :nullify }
      t.timestamps
    end

    add_index :dictionary_lookups, [ :user_id, :created_at ]
  end
end
