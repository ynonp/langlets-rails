class RemoveOldTextColumnsFromPhrases < ActiveRecord::Migration[8.0]
  def up
    # Remove old text columns
    remove_column :phrases, :text_l1, :string
    remove_column :phrases, :text_l2, :string
    
    # Make new columns not null (they should all be populated by now)
    change_column_null :phrases, :text_l1_id, false
    change_column_null :phrases, :text_l2_id, false
  end

  def down
    # Add back old text columns
    add_column :phrases, :text_l1, :string
    add_column :phrases, :text_l2, :string
    
    # Make new columns nullable again
    change_column_null :phrases, :text_l1_id, true
    change_column_null :phrases, :text_l2_id, true
    
    # Populate old columns from multi-script texts
    Phrase.find_each do |phrase|
      if phrase.text_l1_multi.present?
        phrase.update_column(:text_l1, phrase.text_l1_multi.default_content)
      end
      if phrase.text_l2_multi.present?
        phrase.update_column(:text_l2, phrase.text_l2_multi.default_content)
      end
    end
  end
end
