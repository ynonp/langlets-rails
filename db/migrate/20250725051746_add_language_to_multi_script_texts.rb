class AddLanguageToMultiScriptTexts < ActiveRecord::Migration[8.0]
  def change
    add_reference :multi_script_texts, :language
    add_column :multi_script_texts, :audio_status, :integer, default: 0
  end
end
