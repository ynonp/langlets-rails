class AddIndexTypeToTokenTranslations < ActiveRecord::Migration[8.0]
  def change
    add_column :token_translations, :index_type, :integer, default: 0, null: false
    add_index :token_translations, :index_type

    remove_index :token_translations, name: :idx_on_phrase_id_l1_start_index_l1_end_index_22c662cc13

    add_index :token_translations,
      [ :phrase_id, :l1_start_index, :l1_end_index, :index_type ],
      unique: true,
      name: :idx_token_translations_unique
  end
end
