class BackToSingleScript < ActiveRecord::Migration[8.0]
  def change
    # 1. Remove all relevant foreign keys first to untangle dependencies
    remove_foreign_key :phrases, :multi_script_texts, column: :text_l1_id
    remove_foreign_key :phrases, :multi_script_texts, column: :text_l2_id
    remove_foreign_key :languages, :scripts, column: :default_script_id

    # 2. Remove all obsolete columns (including type for reversibility)
    remove_column :phrases, :text_l1_id, :bigint
    remove_column :phrases, :text_l2_id, :bigint
    remove_column :languages, :default_script_id, :bigint
    remove_column :courses, :hebrew_script_available, :boolean

    # 3. Now it's safe to drop the obsolete tables
    drop_table :script_variants, force: :cascade
    drop_table :multi_script_texts, force: :cascade
    drop_table :scripts, force: :cascade

    # 4. Finally, add the new columns to the phrases table
    add_column :phrases, :text_l1, :string
    add_column :phrases, :text_l2, :string
  end
end
