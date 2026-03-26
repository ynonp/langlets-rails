class CreateTokenTranslationUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :token_translation_users do |t|
      t.references :user, null: false, foreign_key: true
      t.references :token_translation, null: false, foreign_key: true

      t.timestamps
    end
    add_index :token_translation_users, [:user_id, :token_translation_id], unique: true, name: 'idx_token_translation_users_unique'
  end
end
