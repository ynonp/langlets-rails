class AddDefaultScriptToLanguages < ActiveRecord::Migration[8.0]
  def change
    add_reference :languages, :default_script, null: true, foreign_key: { to_table: :scripts }
  end
end