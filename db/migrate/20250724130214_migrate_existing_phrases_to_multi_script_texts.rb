class MigrateExistingPhrasesToMultiScriptTexts < ActiveRecord::Migration[8.0]
  def up
    # Iterate through all existing phrases and convert them
    Phrase.find_each do |phrase|
      next unless phrase.text_l1.present? && phrase.text_l2.present?
      
      # Create MultiScriptText for L1 text
      l1_text = MultiScriptText.create!(language: phrase.l1)
      ScriptVariant.create!(
        multi_script_text: l1_text,
        script: phrase.l1.default_script,
        content: phrase.text_l1
      )
      
      # Create MultiScriptText for L2 text
      l2_text = MultiScriptText.create!(language: phrase.l2)
      ScriptVariant.create!(
        multi_script_text: l2_text,
        script: phrase.l2.default_script,
        content: phrase.text_l2
      )
      
      # Update the phrase with the new references
      phrase.update!(text_l1_id: l1_text.id, text_l2_id: l2_text.id)
    end
  end

  def down
    # Remove the multi-script text data (keep the original text columns intact)
    Phrase.update_all(text_l1_id: nil, text_l2_id: nil)
    MultiScriptText.destroy_all
  end
end
