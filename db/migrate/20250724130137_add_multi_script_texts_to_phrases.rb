class AddMultiScriptTextsToPhrases < ActiveRecord::Migration[8.0]
  def change
    add_reference :phrases, :text_l1, null: true, foreign_key: { to_table: :multi_script_texts }
    add_reference :phrases, :text_l2, null: true, foreign_key: { to_table: :multi_script_texts }
  end
end
