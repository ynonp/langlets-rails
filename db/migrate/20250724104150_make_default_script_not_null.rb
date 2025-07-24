class MakeDefaultScriptNotNull < ActiveRecord::Migration[8.0]
  def change
    change_column_null :languages, :default_script_id, false
  end
end
