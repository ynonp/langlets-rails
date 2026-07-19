class SupportMultipleTranslationLanguages < ActiveRecord::Migration[8.0]
  def up
    create_table :phrase_translations, if_not_exists: true do |t|
      t.references :phrase, null: false, foreign_key: { on_delete: :cascade }
      t.references :language, null: false, foreign_key: true
      t.string :text
      t.timestamps
    end
    add_index :phrase_translations, [ :phrase_id, :language_id ], unique: true, if_not_exists: true

    # The old token_translations rows contain both the language-neutral L1 span
    # and one L2 rendering. Preserve their ids while splitting the two concepts.
    if table_exists?(:token_translations) && column_exists?(:token_translations, :phrase_id) && !table_exists?(:phrase_tokens)
      rename_table :token_translations, :phrase_tokens
      rename_index_if_present :phrase_tokens, :idx_token_translations_unique, :idx_phrase_tokens_unique
      rename_index_if_present :phrase_tokens, :index_token_translations_on_phrase_id, :index_phrase_tokens_on_phrase_id
      rename_index_if_present :phrase_tokens, :index_token_translations_on_index_type, :index_phrase_tokens_on_index_type

      add_index :phrase_tokens,
        [ :phrase_id, :l1_start_index, :l1_end_index, :index_type ],
        unique: true,
        name: :idx_phrase_tokens_unique,
        if_not_exists: true
      add_index :phrase_tokens, :phrase_id, if_not_exists: true
      add_index :phrase_tokens, :index_type, if_not_exists: true
    end

    create_table :token_translations, if_not_exists: true do |t|
      t.references :phrase_token, null: false, foreign_key: { on_delete: :cascade }
      t.references :language, null: false, foreign_key: true
      t.string :translation
      t.integer :l2_start_index
      t.integer :l2_end_index
      t.timestamps
    end
    add_index :token_translations, [ :phrase_token_id, :language_id ], unique: true, if_not_exists: true

    rename_table :activity_token_translations, :activity_phrase_tokens if table_exists?(:activity_token_translations) && !table_exists?(:activity_phrase_tokens)
    rename_column :activity_phrase_tokens, :token_translation_id, :phrase_token_id if column_exists?(:activity_phrase_tokens, :token_translation_id)
    rename_table :token_translation_users, :phrase_token_users if table_exists?(:token_translation_users) && !table_exists?(:phrase_token_users)
    rename_column :phrase_token_users, :token_translation_id, :phrase_token_id if column_exists?(:phrase_token_users, :token_translation_id)
    add_reference :phrase_token_users, :language, foreign_key: true unless column_exists?(:phrase_token_users, :language_id)

    create_table :course_translations, if_not_exists: true do |t|
      t.references :course, null: false, foreign_key: { on_delete: :cascade }
      t.references :language, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :name, null: false
      t.timestamps
    end
    add_index :course_translations, [ :course_id, :language_id ], unique: true, if_not_exists: true

    create_table :lesson_translations, if_not_exists: true do |t|
      t.references :lesson, null: false, foreign_key: { on_delete: :cascade }
      t.references :language, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :lesson_translations, [ :lesson_id, :language_id ], unique: true, if_not_exists: true

  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the multilingual backfill cannot be safely merged back"
  end

  private

  def rename_index_if_present(table, old_name, new_name)
    return unless index_name_exists?(table, old_name)
    return if index_name_exists?(table, new_name)

    rename_index table, old_name, new_name
  end
end
